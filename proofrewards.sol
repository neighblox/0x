// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProofRewards is Context, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 rewardToken;
    uint256 private rewardsCap = 100000000 * 10 ** 18;
    uint private rewardAmount = 5 * 10 ** 0;
    // Index of next created Merkle root.
    uint256 public nextCreatedIndex;
    // Track which accounts have claimed for each window index.
    // Note: uses a packed array of bools for gas optimization on tracking certain claims. Copied from Uniswap's contract.
    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;
    mapping(address => bool) whitelisted;
    mapping(uint256 => Window) public merkleWindows;
    mapping(uint256 => Claim) public _claims;

    modifier isWhitelisted(address _address) {
        require(whitelisted[_address], "You need to be whitelisted for this transaction");
        _;
    }

    struct Window {
        uint256 transactionIndex;
        bytes32 merkleRoot;
        uint256 closeTime;
        bool is_open;
    }

    struct Data {
        bytes32 merkleRoot;
        uint256 closeTime;
        bool is_open;
    }

    mapping(uint256 => Data) public data_;

    // Represents an account's claim for `amount` within the Merkle root located at the `windowIndex`.
    struct Claim {
        uint256 windowIndex;
        uint256 rewardAmount;
        uint256 accountIndex; // Used only for bitmap. Assumed to be unique for each claim.
        address account;
        bytes32[] merkleProof;
    }

    event CreatedWindow(
        uint256 indexed windowIndex,
        IERC20 indexed rewardToken,
        bytes32 merkleRoot,
        bool is_open
    );

    event Claimed(
        address indexed caller,
        uint256 windowIndex,
        address indexed account,
        uint256 accountIndex,
        uint256 rewardAmount,
        IERC20 indexed rewardToken
    );

    constructor(
        IERC20 token
    )
    Ownable()
    {
     rewardToken = token;
    }

    function setWindow(
        uint256 transactionIndex,
        bytes32 merkleRoot,
        uint256 closeTime
    )
    external onlyOwner returns(uint256)
    {
        uint256 close_time = closeTime;
        _setWindow(transactionIndex, merkleRoot, close_time, true);
        return(transactionIndex);
    }

    function claim(
        uint256 transactionIndex,
        uint256 accountIndex,
        address account,
        bytes32[] calldata merkleProof
    ) public returns(bool){
        Claim memory claim_ = _claims[transactionIndex];
        claim_.rewardAmount = rewardAmount;
        claim_.accountIndex = accountIndex;
        claim_.account = account;
        claim_.merkleProof = merkleProof;
        _verifyAndMarkClaimed(claim_);
        rewardToken.safeTransfer(claim_.account, claim_.rewardAmount);
        return true;
    }

    /**
    * @notice Returns True if the claim for `accountIndex` has already been completed for the Merkle root at
    *         `windowIndex`.
    * @dev    This method will only work as intended if all `accountIndex`'s are unique for a given `windowIndex`.
    *         The onus is on the Owner of this contract to submit only valid Merkle roots.
    * @param windowIndex merkle root to check.
    * @param accountIndex account index to check within window index.
    * @return True if claim has been executed already, False otherwise.
    */
    function isClaimed(uint256 windowIndex, uint256 accountIndex) public view returns (bool) {
        uint256 claimedWordIndex = accountIndex / 256;
        uint256 claimedBitIndex = accountIndex % 256;
        uint256 claimedWord = claimedBitMap[windowIndex][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /**
    * @notice Returns True if leaf described by {account, amount, accountIndex} is stored in Merkle root at given
    *         window index.
    * @param _claim claim object describing amount, accountIndex, account, window index, and merkle proof.
    * @return valid True if leaf exists.
    */
    function verifyClaim(Claim memory _claim) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_claim.account, _claim.rewardAmount, _claim.accountIndex));
        return MerkleProof.verify(_claim.merkleProof, merkleWindows[_claim.windowIndex].merkleRoot, leaf);
    }

    // Store new Merkle root at `windowindex`. Pull `rewardsDeposited` from caller to seed distribution for this root.
    function _setWindow(
        uint256 transactionIndex,
        bytes32 merkleRoot,
        uint256 closeTime,
        bool is_open
    ) private {
        Window storage window = merkleWindows[transactionIndex];
        window.merkleRoot = merkleRoot;
        window.closeTime = closeTime;
        window.is_open = is_open;

        emit CreatedWindow(transactionIndex, rewardToken, merkleRoot, true);

        rewardToken.safeTransferFrom(msg.sender, address(this), rewardAmount);
    }

    // Mark claim as completed for `accountIndex` for Merkle root at `windowIndex`.
    function _setClaimed(uint256 windowIndex, uint256 accountIndex) private {
        uint256 claimedWordIndex = accountIndex / 256;
        uint256 claimedBitIndex = accountIndex % 256;
        claimedBitMap[windowIndex][claimedWordIndex] =
        claimedBitMap[windowIndex][claimedWordIndex] |
        (1 << claimedBitIndex);
    }

    // Verify claim is valid and mark it as completed in this contract.
    function _verifyAndMarkClaimed(Claim memory _claim) private {
        // Check claimed proof against merkle window at given index.
        require(verifyClaim(_claim), "Incorrect merkle proof");
        // Check the account has not yet claimed for this window.
        require(!isClaimed(_claim.windowIndex, _claim.accountIndex), "Account has already claimed for this window");

        // Proof is correct and claim has not occurred yet, mark claimed complete.
        _setClaimed(_claim.windowIndex, _claim.accountIndex);

        emit Claimed(
            msg.sender,
            _claim.windowIndex,
            _claim.account,
            _claim.accountIndex,
            _claim.rewardAmount,
            IERC20(rewardToken)
        );
    }

}
