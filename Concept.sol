pragma solidity ^0.4.19;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Main {
    using SafeMath for uint256;
    
    struct Transaction {
        address from;
        address to;
        string secret_from;
        string secret_to;
        string pub1; // task to solve #1
        string pub2; // task to solve #2
        uint256 priv1; // proof of hack of solve #1
        uint256 priv2; // proof of hack of solve #2
        string hashOfPriv1; // hash of private #1
        string hashOfPriv2; // hash of private #2
        bool mined; // true/false is transaction mined
        bool filled; // true/false is transaction filled and ready to mine 
    }
    uint256 numTransactions;
    mapping (uint256 => Transaction) transactions;
    
    uint256 difficulty;
    
    event New(address from, address to, uint256 id);
    event MineMe(uint256 id);
    
    // ---- erc20 ---- 
    mapping (address => uint256) public erc20tokens;
    event Transfer(address indexed from, address indexed to, uint tokens);
    function balanceOf(address _address) public view returns (uint256 balance) {
        return erc20tokens[_address];
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        erc20tokens[msg.sender] = erc20tokens[msg.sender].sub(tokens);
        erc20tokens[to] = erc20tokens[to].add(tokens);
        Transfer(msg.sender, to, tokens);
        return true;
    }
    // ---- /erc20 ---- 
    
    function mined(string _privKey1, string _privKey2, uint transactionID) public returns (uint256) {
        require(sha3(_privKey1) == transactions[transactionID].hashOfPriv1);
        require(sha3(_privKey2) == transactions[transactionID].hashOfPriv2);
        transactions[transactionID].priv1 = _privKey1;
        transactions[transactionID].priv2 = _privKey2;
        transactions[transactionID].mined = true;
        erc20tokens[msg.sender].add(1);
        Transfer(address(this), msg.sender, tokens);
        return erc20tokens[msg.sender];
    }
    
    function getTransactionPrivs(uint transactionID) public returns (uint256, uint256) {
        return (transactions[transactionID].priv1, transaction[transactionID].priv2)
    }
    
    // TODO: who can do it?
    function setDifficulty(uint newDiff) public returns (bool) {
        difficulty = newDiff;
        return true;
    }

    function newTransaction(string secret, address _address, string _public, string _hash) public returns (uint256) {
        transactionID = numTransactions++;
        transactions[transactionID] = Transaction(msg.sender, _address, secret, '', _public, '', 0, 0, _hash, '', false, false);
        New(msg.sender, _address, transactionID);
        return transactionID;
    }
    
    function approveTransaction(uint transactionID, string secret, string _public, string _hash) public returns (uint256) {
        currentTransaction = transactions[transactionID];
        require(currentTransaction.to == msg.sender);
        
        currentTransaction.secret_to = secret;
        currentTransaction.pub2 = _public;
        currentTransaction.hashOfPriv2 = _hash;
        currentTransaction.filled = true;
        MineMe(transactionID);
        return transactionID;
    }
    
    function Main() {
        difficulty = 2000;
    }
}
