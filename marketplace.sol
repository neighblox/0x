// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./rewardsDistributor.sol";

contract Marketplace is Context, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 nblxc;
    ProofRewards public rewardsDistribution;
    uint256 public nextTransactionIndex;

    // Represents an account's claim for `amount` within the Merkle root located at the `windowIndex`.
    struct Transaction {
        uint256 transactionIndex;
        uint32 amount;
        address buyer;
        string buyer_id;
        bytes32 items;
        address seller;
        string seller_id;
        IERC20 token;
        bytes32[] checks;
        uint256 timestamp;
        bool completed;
        uint256 eta;
    }

    struct Claim {
        uint256 transactionIndex;
        uint256 rewardAmount;
        uint256 accountIndex; // Used only for bitmap. Assumed to be unique for each claim.
        address account;
        bytes32[] merkleProof;
    }

    mapping(address => bool) whitelisted;
    // Transactions are mapped to arbitrary indices.
    mapping(uint256 => Transaction) public transactions;

    event CreatedTransaction(
        uint256 transactionIndex,
        uint32 amount,
        address buyer,
        string buyer_id,
        bytes32 items,
        address seller,
        string seller_id,
        uint256 timestamp,
        uint256 eta
    );

    /****************************
    *      MODIFIERS
    ****************************/
    modifier isWhitelisted(address _address) {
        require(whitelisted[_address], "You need to be whitelisted for this transaction");
        _;
    }

    constructor(IERC20 token) Ownable() { nblxc = token; rewardsDistribution = new ProofRewards(nblxc); }

    function whitelistForTransaction(address account) public virtual onlyOwner {
        require(_msgSender() == owner(), "Only contract owner can whitelist accounts");
        whitelisted[account] = true;
    }

    function createTransaction(
        uint32 amount,
        address buyer,
        string calldata buyer_id,
        bytes32 items,
        address seller,
        string calldata seller_id,
        bytes32 merkleRoot,
        uint256 eta
    ) public onlyOwner() returns(uint256[2] memory){
        uint256 trI = nextTransactionIndex;
        nextTransactionIndex = trI.add(1);
        Transaction storage transaction = transactions[nextTransactionIndex];
        transaction.transactionIndex = nextTransactionIndex;
        transaction.amount = amount;
        transaction.buyer = buyer;
        transaction.buyer_id = buyer_id;
        transaction.items = items;
        transaction.seller = seller;
        transaction.seller_id = seller_id;
        transaction.eta = block.timestamp + eta;

        uint256 timestamp = block.timestamp;

        emit CreatedTransaction(trI, amount, buyer, buyer_id, items, seller, seller_id, timestamp, block.timestamp + eta);

        uint256 windowIndex = rewardsDistribution.setWindow(nextTransactionIndex, merkleRoot, block.timestamp + eta);
        uint[2] memory arr;
        arr = [trI, windowIndex];
        return(arr);

    }

    function processTransactionForBuyer(
        uint256 transactionIndex,
        uint256 accountIndex,
        bytes32[] calldata merkleProof
    ) public returns(bool){
        Transaction storage tr = transactions[transactionIndex];
        rewardsDistribution.claim(transactionIndex,  accountIndex, tr.buyer, merkleProof);
        return true;
    }

    function processTransactionForSeller(
        uint256 transactionIndex,
        uint256 accountIndex,
        bytes32[] calldata merkleProof
    ) public returns(bool){
        Transaction storage tr = transactions[transactionIndex];
        rewardsDistribution.claim(transactionIndex,  accountIndex, tr.seller, merkleProof);
        return true;
    }
}
