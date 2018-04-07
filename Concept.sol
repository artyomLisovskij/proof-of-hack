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
        bool mined; // true/false is transaction mined
        bool filled; // true/false is transaction filled and ready to mine 
    }
    uint256 numTransactions;
    mapping (uint256 => Transaction) transactions;
    
    uint256 difficulty;
    
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
        // if sha3(_privKey1 == hash1 && _privKey2 == hash2)
        // put them to transaction
        erc20tokens[msg.sender].add(1);
        Transfer(address(this), msg.sender, tokens);
        return erc20tokens[msg.sender];
    }
    
    function getTransactionPrivs(uint transactionID) public returns (uint256, uint256) {
        return (transactions[transactionID].priv1, transaction[transactionID].priv2)
    }
    
    function getTransaction(uint transactionID) public returns (address, address, bool, string, string) {
        return transactions[transactionID].priv1 
    }
    
    function Main() {
        // create 0 block and 0 transaction
        difficulty = 2000;
        tokens[msg.sender].add(10);
        newTransaction(msg.sender, 10, '');
    }
}
