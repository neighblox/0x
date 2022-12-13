// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IKycContract {
    function setKycForGenesis(address _addr) external;

    function setKycForSecondStage(address _addr) external;

    function setKycForThirdStage(address _addr) external;

    function setKycForFourthStage(address _addr) external;

    function revokedForGenesis(address _addr) external;

    function revokedForSecondStage(address _addr) external;

    function revokedForThirdStage(address _addr) external;

    function revokedForFourthStage(address _addr) external;

    function kycStatusForGenesis(address _addr) external view returns(bool);

    function kycStatusForSecondStage(address _addr) external view returns(bool);

    function kycStatusForThirdStage(address _addr) external view returns(bool);

    function kycStatusForFourthStage(address _addr) external view returns(bool);
}

interface IFinance {
    function deposit(uint256 _amount) external;
}

contract Crowdsale is Context, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address kyc;
    address finance;

    // ICO Stage
    // ============
    enum CrowdsaleStage { Genesis, SecondStage, ThirdStage, FourthStage }
    CrowdsaleStage public stage = CrowdsaleStage.Genesis; // By default it's Genesis
    // =============

    // The token being sold
    IERC20 private _token;
    //The token being used for purchase
    ERC20 internal stableToken;

    // Address where funds are collected
    address payable private _wallet;

    string private constant INSUFFICIENT_PAYMENT = "INSUFFICIENT_PAYMENT";
    string private constant EXCEEDED_PAYMENT = "EXCEEDED_PAYMENT";
    string private constant TOKENS_NOT_AVAILABLE = "TOKENS_NOT_AVAILABLE";
    string private constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string private constant REFERRER_NA = "REFERRER_N/A";

    // How many token units a buyer gets per dai.
    // The rate is the conversion between dai and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 0.6 dai will give you 1 unit, or 0.001 TOK.
    uint256 private rate;

    // Amount of dai raised
    uint256 private _daiRaised;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value dais paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event TransferSent(address _from, address _destAddr, uint _amount);

    modifier canBuyInGenesisRound(address addy, address _kyc) {
        require(IKycContract(_kyc).kycStatusForGenesis(msg.sender), "not whitelisted to buy tokens during Genesis Stage of the pNBLX ICO!");
        _;
    }

    modifier canBuyInSecondStage(address addy, address _kyc) {
        require(IKycContract(_kyc).kycStatusForSecondStage(msg.sender), "not whitelisted to buy tokens during Second Stage of the pNBLX ICO!");
        _;
    }

    modifier canBuyInThirdStage(address addy, address _kyc) {
        require(IKycContract(_kyc).kycStatusForThirdStage(msg.sender), "not whitelisted to buy tokens during Third Stage of the pNBLX ICO!");
        _;
    }

    modifier canBuyInFourthStage(address addy, address _kyc) {
        require(IKycContract(_kyc).kycStatusForFourthStage(msg.sender), "not whitelisted to buy tokens during Fourth Stage of the pNBLX ICO!");
        _;
    }

    event Buy(uint256 amount, address buyer);

    /*x
     * @dev The rate is the conversion between dai and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 dai will give you 1 unit, or 0.001 TOK.
     * @param wallet Address where collected funds will be forwarded to
     * @param token Address of the token being sold
     */
    constructor (address payable wallet, IERC20 token, address _kyc, address financeAddr, address daiAddr) Ownable() {
        require(wallet != address(0), "Crowdsale: wallet is the zero address");
        require(address(token) != address(0), "Crowdsale: token is the zero address");

        _wallet = wallet;
        _token = token;
        kyc = _kyc;
        finance = financeAddr;
        stableToken = ERC20(daiAddr);
    }

    // Change Crowdsale Stage. Available Options: Genesis, Private, ThirdStage, Public
    function setCrowdsaleStage(uint value) public onlyOwner {

        CrowdsaleStage _stage;

        if (uint(CrowdsaleStage.Genesis) == value) {
            _stage = CrowdsaleStage.Genesis;
        } else if (uint(CrowdsaleStage.SecondStage) == value) {
            _stage = CrowdsaleStage.SecondStage;
        } else if (uint(CrowdsaleStage.ThirdStage) == value) {
            _stage = CrowdsaleStage.ThirdStage;
        } else if (uint(CrowdsaleStage.FourthStage) == value) {
            _stage = CrowdsaleStage.FourthStage;
        }

        stage = _stage;

        if (stage == CrowdsaleStage.Genesis) {
            setCurrentRate(6e17);
        } else if (stage == CrowdsaleStage.SecondStage) {
            setCurrentRate(10);
        } else if (stage == CrowdsaleStage.ThirdStage) {
            setCurrentRate(7);
        } else if (stage == CrowdsaleStage.FourthStage) {
            setCurrentRate(4);
        }
    }

    // Change the current rate
    function setCurrentRate(uint256 _rate) private {
        rate = _rate;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    // receive () external payable {
    //     buyTokens(msg.sender, amount);
    // }

    /**
     * @return the amount of dai raised.
     */
    function daiRaised() public view returns (uint256) {
        return _daiRaised;
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary, uint256 amount) public nonReentrant payable {
        if ((stage == CrowdsaleStage.Genesis)) {
            require(IKycContract(kyc).kycStatusForGenesis(msg.sender), "must be whitelisted to buy tokens during Genesis Stage!");
            setCurrentRate(6e17);
            uint256 tokenAmount = amount;
            _preValidatePurchase(beneficiary, tokenAmount);

            // calculate token amount to be created
            uint256 tokens = _getTokenAmount(tokenAmount);

            // update state
            _daiRaised = _daiRaised.add(tokens);

            uint256 balance = _token.balanceOf(address(this));
            require(0 < balance, TOKENS_NOT_AVAILABLE);

            uint256 allowance = stableToken.allowance(msg.sender, address(this));
            require(allowance <= balance, EXCEEDED_PAYMENT);

            if (stableToken.transferFrom(msg.sender, address(this), allowance)) {
                require(stableToken.approve(address(finance), allowance));
                IFinance(finance).deposit(tokens);
                emit Buy(tokenAmount, msg.sender);
                require(_token.transfer(msg.sender, tokenAmount));
            }

            _processPurchase(beneficiary, tokens);
            emit TokensPurchased(_msgSender(), beneficiary, tokenAmount, tokens);

            _updatePurchasingState(beneficiary, tokenAmount);

            _postValidatePurchase(beneficiary, tokenAmount);
        } else if ((stage == CrowdsaleStage.SecondStage)) {
            require(IKycContract(kyc).kycStatusForSecondStage(msg.sender), "must be whitelisted to buy coins during Second Stage!");
            setCurrentRate(10);
            uint256 tokenAmount = amount;
            _preValidatePurchase(beneficiary, tokenAmount);

            // calculate token amount to be created
            uint256 tokens = _getTokenAmount(tokenAmount);

            // update state
            _daiRaised = _daiRaised.add(tokens);

            uint256 balance = _token.balanceOf(address(this));
            require(0 < balance, TOKENS_NOT_AVAILABLE);

            uint256 allowance = stableToken.allowance(msg.sender, address(this));
            require(allowance <= balance, EXCEEDED_PAYMENT);

            if (stableToken.transferFrom(msg.sender, address(this), allowance)) {
                require(stableToken.approve(address(finance), allowance));
                IFinance(finance).deposit(tokens);
                emit Buy(tokenAmount, msg.sender);
                require(_token.transfer(msg.sender, tokenAmount));
            }

            _processPurchase(beneficiary, tokens);
            emit TokensPurchased(_msgSender(), beneficiary, tokenAmount, tokens);

            _updatePurchasingState(beneficiary, tokenAmount);

            _postValidatePurchase(beneficiary, tokenAmount);
        } else if ((stage == CrowdsaleStage.ThirdStage)) {
            require(IKycContract(kyc).kycStatusForThirdStage(msg.sender), "must be whitelisted to buy coins during Third Stage!");
            setCurrentRate(7);
            uint256 tokenAmount = amount;
            _preValidatePurchase(beneficiary, tokenAmount);

            // calculate token amount to be created
            uint256 tokens = _getTokenAmount(tokenAmount);

            // update state
            _daiRaised = _daiRaised.add(tokens);

            uint256 balance = _token.balanceOf(address(this));
            require(0 < balance, TOKENS_NOT_AVAILABLE);

            uint256 allowance = stableToken.allowance(msg.sender, address(this));
            require(allowance <= balance, EXCEEDED_PAYMENT);

            if (stableToken.transferFrom(msg.sender, address(this), allowance)) {
                require(stableToken.approve(address(finance), allowance));
                IFinance(finance).deposit(tokens);
                emit Buy(tokenAmount, msg.sender);
                require(_token.transfer(msg.sender, tokenAmount));
            }

            _processPurchase(beneficiary, tokens);
            emit TokensPurchased(_msgSender(), beneficiary, tokenAmount, tokens);

            _updatePurchasingState(beneficiary, tokenAmount);

            _postValidatePurchase(beneficiary, tokenAmount);
        } else if ((stage == CrowdsaleStage.FourthStage)) {
            require(IKycContract(kyc).kycStatusForFourthStage(msg.sender), "must be whitelisted to buy coins during Fourth Stage!");
            setCurrentRate(4);
            uint256 tokenAmount = amount;
            _preValidatePurchase(beneficiary, tokenAmount);

            // calculate token amount to be created
            uint256 tokens = _getTokenAmount(tokenAmount);

            // update state
            _daiRaised = _daiRaised.add(tokens);

            uint256 balance = _token.balanceOf(address(this));
            require(0 < balance, TOKENS_NOT_AVAILABLE);

            uint256 allowance = stableToken.allowance(msg.sender, address(this));
            require(allowance <= balance, EXCEEDED_PAYMENT);

            if (stableToken.transferFrom(msg.sender, address(this), allowance)) {
                require(stableToken.approve(address(finance), allowance));
                IFinance(finance).deposit(tokens);
                emit Buy(tokenAmount, msg.sender);
                require(_token.transfer(msg.sender, tokenAmount));
            }

            _processPurchase(beneficiary, tokens);
            emit TokensPurchased(_msgSender(), beneficiary, tokenAmount, tokens);

            _updatePurchasingState(beneficiary, tokenAmount);

            _postValidatePurchase(beneficiary, tokenAmount);
        }
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, tokenAmount);
     *     require(daiRaised().add(tokenAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Value in dai involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 tokenAmount) internal view virtual{
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(tokenAmount != 0, "Crowdsale: tokenAmount is 0");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Value in dai involved in the purchase
     */
    function _postValidatePurchase(address beneficiary, uint256 tokenAmount) internal view virtual{
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal virtual{
        uint256 nblxcBalance = _token.balanceOf(address(this));
        require(tokenAmount <= nblxcBalance, "balance is low!!");
        _token.transfer(beneficiary, tokenAmount);
        emit TransferSent(address(this), beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal virtual{
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Value in dai involved in the purchase
     */
    function _updatePurchasingState(address beneficiary, uint256 tokenAmount) internal virtual{
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param tokenAmount Value in dai to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _tokenAmount
     */
    function _getTokenAmount(uint256 tokenAmount) public view returns (uint256) {
        return tokenAmount.mul(rate);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds(uint256 amount) internal {
        IFinance(finance).deposit(amount);
    }
}
