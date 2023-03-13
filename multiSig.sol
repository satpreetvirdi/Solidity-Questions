// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWaller{
    event Deposit(address indexed sender,uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner,uint indexed txId);
    event Execute(uint indexed txId);

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners; // array of owners
    mapping(address =>bool) public isOwner;
    uint public required; // Number of approvals required for transactions

    Transaction[] public transactions;
    mapping(uint => mapping(address =>bool)) public approved;

    modifier onlyOwner(){
        require(isOwner[msg.sender],"Not Owner");
        _;
    }
    modifier txExist(uint _txid){
        require(_txid < transactions.length, "tx doesnt exist");
        _;
    }
    modifier notApproved(uint _txid){
        require(!approved[_txid][msg.sender] ,"Already Approved");
        _;
    }
    modifier notExecuted(uint _txid){
        require(!transactions[_txid].executed,"Tx already Executed");
    }
    constructor(address[] memory _owners, uint _required){
        require(_owners.length > 0 ,"Owners required");
        require(_required>0 && _required >= _owners.length,
        "Invalid number of Owners");
        for(uint i;i<_owners.length;++i){
            address owner = _owners[i];
            require(owner != address(0), "Invalid Owner");
            require(!isOwner[owner],"Owner not unique");
            isOwner[owner]= true;
            owners.push(owner);
        }
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);  
    }

    function submit(address _to,uint _value,bytes calldata _data) external onlyOwner{
        transactions.push(Transaction({
            to : _to,
            value: _value,
            data : _data,
            executed:false
        }));
        emit Submit(transactions.length -1);     
    }
    
    function approve(uint _txid) external onlyOwner txExist(_txid) notApproved(_txid) notExecuted(_txid){
        approved[_txid][msg.sender] =true;
        emit Approve(msg.sender,_txid);
    }   
    function _getApprovalCount(uint _txid) private view returns (uint count){
        for(uint i;i<owners.length;++i){
            if(approved[_txid][owners[i]]){
                count+=1;
            }
        }
    }
    function execute(uint _txid) external txExist(_txid) notExecuted(_txid){
        require(_getApprovalCount(_txid) >= required, "Approval not done");
        Transaction storage transaction = transactions[_txid];
        transaction.executed = true;
        (bool success ) = transaction.to.call{value:transaction.value}{
            transaction.data 
        }
        require(success,"tx failed");
        emit Execute(_txid);
    }
    function revoke(uint _txid)
    external
    onlyOwner
    txExists(_txid)
    notExecuted(_txid){
        require(approved[_txid][msg.sender],"tx not approved");
        approved[_txid][msg.sender] = false;
        emit Revoke(msg.sender,_txid);
    }
}