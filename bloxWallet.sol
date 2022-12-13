// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract BloxWallet {

    address payable private owner;

    //create a mapping so other addresses can interact with this wallet.  Uint8 is used to determine is the address enabled or disabled
    mapping(address => uint8) private _owners;

    //this is the number of signatures we need to sign the contract
    //Since this is a constant we give it a value of 2 (2 people to sign the transaction).
    uint constant MIN_SIGNATURES = 2;

    //A dynamic uint called _transactionIdx that increments
    uint private _transactionIdx;

    //create a struct to represent a transaction that is submitted for others to approve.
    //we need to capture how many people signed the Transaction
    //we need to keep track of who signed (which accounts) the transition
    struct Transaction {
        address payable from;
        address payable to;
        uint amount;
        uint8 signatureCount;
        mapping (address => uint8) signatures;
        uint256 id;
    }

    //This is a mapping of transaction ID to a transaction.
    //you can not call a map to get a list of pending Transactions so we need to create an array below
    // this is private and we are calling this map _transactions
    mapping (uint => Transaction) private _transactions;

    //create a dynamic array called _pendingTransactions
    //this will contain the list of pending transactions that need to be processed
    uint[] private _pendingTransactions;


    //in order to interact with the wallet you need to be the owner so added a require statement then execute the function _;
    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    //require the msg.sender/the owner OR || Or an owner with a 1 which means an enabled owner
    modifier validOwner() {
        require(msg.sender == owner || _owners[msg.sender] == 1, "this is not a valid BloxWallet owner!");
        _;
    }

    constructor() {
        owner = payable(msg.sender);
    }

    event DepositFunds(address from, uint amount);
    event WithdrawFunds(address from, uint amount);
    event TransferFunds(address from, address to, uint amount);
    event TransactionSigned(address by, uint transactionId);
    event TransactionCreated(address from, address to, uint256 amount, uint256 transactionId);
    event TransactionCompleted(address from, address to, uint256 amount, uint256 id);
    event DeleteTransaction(uint256 transactionId);

    //this function is used to add owners of the wallet.  Only the isOwner can add addresses.  1 means enabled
    function addOwner(address _owner)
        isOwner
        public {
        _owners[_owner] = 1;
    }

    //remove an owner from the wallet.  0 means disabled
    function removeOwner(address _owner)
        isOwner
        public {
        _owners[_owner] = 0;
    }

    //anyone can deposit funds into the wallet and emit an event called depositfunds
    fallback ()
        external
        payable
        validOwner {
        emit DepositFunds(msg.sender, msg.value);
    }

    function transferTo(address payable to, uint amount)
        validOwner
        public {
        //make sure the balance is >= the amount of the transaction
        require(address(this).balance >= amount);

        //each Transaction needs a transactionId
        //system will create a transactionId by adding a number to the last id created (hence the use of ++)
        uint transactionId = _transactionIdx++;

        //create a transaction using the struct and put in memory
        //then add the information to the Transaction in memory
        //set the signature count to 0 which means it has not been signed
        Transaction storage transaction = _transactions[transactionId];
        transaction.from = payable (msg.sender);
        transaction.to = to;
        transaction.amount = amount;
        transaction.signatureCount = 0;
        transaction.id = transactionId;

        //add the transaction to the _transactions data structure (transaction map)
        //Transaction ID to the actual transaction
        //Add this transaction to the dynamic array using the push mechanism using the transactionId
        // _transactions[transactionId] = transaction;
        _pendingTransactions.push(transactionId);
        //create an event that the transaction was created
        emit TransactionCreated(msg.sender, to, amount, transactionId);

    }

    //get a list of pending transactions
    //you need to be an owner
    //returns the array of pending transactions
    function getPendingTransactions()
        validOwner
        public
        view
        returns (uint[] memory) {
        return _pendingTransactions;
    }

    receive() external payable {}

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "caller is not owner");
        payable(msg.sender).transfer(amount);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    //Sign and if meets minimum required signatures then execute the transaction
    function signTransaction(uint transactionId)
        validOwner
        public {

        //because the transaction was in "memory" to reference it we use storage
        //go to _transactions and get the transactionId and give it the variable name transaction
        Transaction storage transaction = _transactions[transactionId];

        //Transaction must exist
        require(address(0x0) != transaction.from);
        //creator cannot sign the transaction
        require(msg.sender != transaction.from);
        //cannot sign the transaction more then once
        require(transaction.signatures[msg.sender] != 1);

        //sign the tranaction
        transaction.signatures[msg.sender] = 1;
        //increment the signatureCount by 1
        transaction.signatureCount++;
        //emit an event
        emit TransactionSigned(msg.sender, transactionId);

        //if the transaction has a signature count >= the minimum signatures we can process the transaction
        //then we need to validate the transaction
        if(transaction.signatureCount >= MIN_SIGNATURES) {
            //check balance
            require(address(this).balance >= transaction.amount);
            transaction.to.transfer(transaction.amount);
            //emit an event
            emit TransactionCompleted(transaction.from, transaction.to, transaction.amount, transaction.id);
            //delete the transaction id
            emit DeleteTransaction(transactionId);
        }
}
}
