pragma solidity ^0.4.19;

library StringUtils {
    /// @dev Does a byte-by-byte lexicographical comparison of two strings.
    /// @return a negative number if `_a` is smaller, zero if they are equal
    /// and a positive numbe if `_b` is smaller.
    function compare(string _a, string _b) pure public returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        //@todo unroll the loop into increments of 32 and do full 32 byte comparisons
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }
    /// @dev Compares two strings and returns true iff they are equal.
    function equal(string _a, string _b) pure public returns (bool) {
        return compare(_a, _b) == 0;
    }
    /// @dev Finds the index of the first occurrence of _needle in _haystack
    function indexOf(string _haystack, string _needle) pure public returns (int)
    {
    	bytes memory h = bytes(_haystack);
    	bytes memory n = bytes(_needle);
    	if(h.length < 1 || n.length < 1 || (n.length > h.length)) 
    		return -1;
    	else if(h.length > (2**128 -1)) // since we have to be able to return -1 (if the char isn't found or input error), this function must return an "int" type with a max length of (2^128 - 1)
    		return -1;									
    	else
    	{
    		uint subindex = 0;
    		for (uint i = 0; i < h.length; i ++)
    		{
    			if (h[i] == n[0]) // found the first char of b
    			{
    				subindex = 1;
    				while(subindex < n.length && (i + subindex) < h.length && h[i + subindex] == n[subindex]) // search until the chars don't match or until we reach the end of a or b
    				{
    					subindex++;
    				}	
    				if(subindex == n.length)
    					return int(i);
    			}
    		}
    		return -1;
    	}	
    }
}

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
        string priv1; // proof of hack of solve #1
        string priv2; // proof of hack of solve #2
        string hashOfPriv1; // hash of private #1
        string hashOfPriv2; // hash of private #2
        bool mined; // true/false is transaction mined
        bool filled; // true/false is transaction filled and ready to mine 
    }
    uint256 numTransactions;
    mapping (uint256 => Transaction) transactions;
    
    uint256 public difficulty;
    
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
        emit Transfer(msg.sender, to, tokens);
        return true;
    }
    // ---- /erc20 ----
    function bytes32ToString(bytes32 x) pure public returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    function mined(string _privKey1, string _privKey2, uint transactionID) public returns (uint256) {
        require(transactions[transactionID].mined==false);
        require( StringUtils.equal(bytes32ToString(keccak256(_privKey1)), transactions[transactionID].hashOfPriv1));
        require( StringUtils.equal(bytes32ToString(keccak256(_privKey2)), transactions[transactionID].hashOfPriv2));
        transactions[transactionID].priv1 = _privKey1;
        transactions[transactionID].priv2 = _privKey2;
        transactions[transactionID].mined = true;
        erc20tokens[msg.sender].add(1);
        emit Transfer(address(this), msg.sender, 1);
        return erc20tokens[msg.sender];
    }
    
    function getTransactionPrivs(uint transactionID) view public returns (string, string) {
        return (transactions[transactionID].priv1, transactions[transactionID].priv2);
    }
    
    // TODO: who can do it?
    function setDifficulty(uint newDiff) public returns (bool) {
        difficulty = newDiff;
        return true;
    }

    function newTransaction(string secret, address _address, string _public, string _hash) public returns (uint256) {
        uint transactionID = numTransactions++;
        transactions[transactionID] = Transaction(msg.sender, _address, secret, '', _public, '', '', '', _hash, '', false, false);
        emit New(msg.sender, _address, transactionID);
        return transactionID;
    }
    
    function approveTransaction(uint transactionID, string secret, string _public, string _hash) public returns (uint256) {
        Transaction storage currentTransaction = transactions[transactionID];
        require(currentTransaction.to == msg.sender);
        
        currentTransaction.secret_to = secret;
        currentTransaction.pub2 = _public;
        currentTransaction.hashOfPriv2 = _hash;
        currentTransaction.filled = true;
        emit MineMe(transactionID);
        return transactionID;
    }
    
    function Main() public {
        difficulty = 2000;
    }
}
