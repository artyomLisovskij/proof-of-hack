pragma solidity ^0.4.19;

contract VanityLib {
    uint constant m = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;

    function lengthOfCommonPrefix(bytes a, bytes b) public pure returns(uint) {
        uint len = (a.length <= b.length) ? a.length : b.length;
        for (uint i = 0; i < len; i++) {
            if (a[i] != b[i]) {
                return i;
            }
        }
        return len;
    }
    
    function lengthOfCommonPrefix32(bytes32 a, bytes b) public pure returns(uint) {
        for (uint i = 0; i < b.length; i++) {
            if (a[i] != b[i]) {
                return i;
            }
        }
        return b.length;
    }

    function lengthOfCommonPrefix3232(bytes32 a, bytes32 b) public pure returns(uint) {
        for (uint i = 0; i < 32; i++) {
            if (a[i] != b[i] || a[i] == 0) {
                return i;
            }
        }
        return 0;
    }
    
    function equalBytesToBytes(bytes a, bytes b) public pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        for (uint i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }
    
    function equalBytes32ToBytes(bytes32 a, bytes b) public pure returns (bool) {
        for (uint i = 0; i < b.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }
    
    function bytesToBytes32(bytes source) public pure returns(bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }

    /* Converts given number to base58, limited by 32 symbols */
    function toBase58Checked(uint256 _value, byte appCode) public pure returns(bytes32) {
        string memory letters = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
        bytes memory alphabet = bytes(letters);
        uint8 base = 58;
        uint8 len = 0;
        uint256 remainder = 0;
        bool needBreak = false;
        bytes memory bytesReversed = bytes(new string(32));
        
        for (uint8 i = 0; true; i++) {
            if (_value < base) {
                needBreak = true;
            }
            remainder = _value % base;
            _value = uint256(_value / base);
            if (len == 32) {
                for (uint j = 0; j < len - 1; j++) {
                    bytesReversed[j] = bytesReversed[j + 1];
                }
                len--;
            }
            bytesReversed[len] = alphabet[remainder];
            len++;
            if (needBreak) {
                break;
            }
        }
        
        // Reverse
        bytes memory result = bytes(new string(32));
        result[0] = appCode;
        for (i = 0; i < 31; i++) {
            result[i + 1] = bytesReversed[len - 1 - i];
        }
        
        return bytesToBytes32(result);
    }

    // Create BTC Address: https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses#How_to_create_Bitcoin_Address
    function createBtcAddressHex(uint256 publicXPoint, uint256 publicYPoint) public pure returns(uint256) {
        bytes20 publicKeyPart = ripemd160(sha256(byte(0x04), publicXPoint, publicYPoint));
        bytes32 publicKeyCheckCode = sha256(sha256(byte(0x00), publicKeyPart));
        
        bytes memory publicKey = new bytes(32);
        for (uint i = 0; i < 7; i++) {
            publicKey[i] = 0x00;
        }
        publicKey[7] = 0x00; // Main Network
        for (uint j = 0; j < 20; j++) {
            publicKey[j + 8] = publicKeyPart[j];
        }
        publicKey[28] = publicKeyCheckCode[0];
        publicKey[29] = publicKeyCheckCode[1];
        publicKey[30] = publicKeyCheckCode[2];
        publicKey[31] = publicKeyCheckCode[3];
        
        return uint256(bytesToBytes32(publicKey));
    }
    
    function createBtcAddress(uint256 publicXPoint, uint256 publicYPoint) public pure returns(bytes32) {
        return toBase58Checked(createBtcAddressHex(publicXPoint, publicYPoint), "1");
    }

    // https://github.com/stonecoldpat/anonymousvoting/blob/master/LocalCrypto.sol
    function invmod(uint256 a, uint256 p) public pure returns (uint256) {
        int t1 = 0;
        int t2 = 1;
        uint r1 = p;
        uint r2 = a;
        uint q;
        while (r2 != 0) {
            q = r1 / r2;
            (t1, t2, r1, r2) = (t2, t1 - int(q) * t2, r2, r1 - q * r2);
        }

        return t1 < 0 ? p - uint(-t1) : uint(t1);
    }
    
    // https://github.com/stonecoldpat/anonymousvoting/blob/master/LocalCrypto.sol
    function submod(uint a, uint b, uint p) public pure returns (uint) {
        return addmod(a, p - b, p);
    }

    // https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication#Point_addition
    // https://github.com/bellaj/Blockchain/blob/6bffb47afae6a2a70903a26d215484cf8ff03859/ecdsa_bitcoin.pdf
    // https://math.stackexchange.com/questions/2198139/elliptic-curve-formulas-for-point-addition
    function addXY(uint x1, uint y1, uint x2, uint y2) public pure returns(uint x3, uint y3) {
        uint anti = invmod(submod(x1, x2, m), m);
        uint alpha = mulmod(submod(y1, y2, m), anti, m);
        x3 = submod(submod(mulmod(alpha, alpha, m), x1, m), x2, m);
        y3 = submod(mulmod(alpha, submod(x2, x3, m), m), y2, m);
        
        // x3 = bytes32(mul_mod(uint(x3), uint(y3), m)); == 1!!!!
        
        // https://github.com/jbaylina/ecsol/blob/master/ec.sol
        // x3 = addmod(mulmod(y2, x1, m), mulmod(x2, y1, m), m);
        // y3 = mulmod(y1, y2, m);
    }

    function doubleXY(uint x1, uint y1) public pure returns(uint x2, uint y2) {
        uint anti = invmod(addmod(y1, y1, m), m);
        uint alpha = mulmod(addmod(addmod(mulmod(x1, x1, m), mulmod(x1, x1, m), m), mulmod(x1, x1, m), m), anti, m);
        x2 = submod(mulmod(alpha, alpha, m), addmod(x1, x1, m), m);
        y2 = submod(mulmod(alpha, submod(x1, x2, m), m), y1, m);
    }

    function mulXY(uint x1, uint y1, uint privateKey) public pure returns(uint x2, uint y2) {
        bool addition = false;
        for (uint i = 0; i < 256; i++) {
            if (((privateKey >> i) & 1) == 1) {
                if (addition) {
                    (x2, y2) = addXY(x1, y1, x2, y2);
                } else {
                    (x2, y2) = (x1, y1);
                    addition = true;
                }
            }
            (x1,y1) = doubleXY(x1, y1);
        }
    }

    function bitcoinPublicKey(uint256 privateKey) public pure returns(uint, uint) {
        uint256 gx = 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798;
        uint256 gy = 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8;
        return mulXY(gx, gy, privateKey);
    }

    function complexityForBtcAddressPrefix(bytes prefix) public pure returns(uint) {
        return complexityForBtcAddressPrefixWithLength(prefix, prefix.length);
    }

    // https://bitcoin.stackexchange.com/questions/48586
    function complexityForBtcAddressPrefixWithLength(bytes prefix, uint length) public pure returns(uint) {
        require(prefix.length >= length);
        
        uint8[128] memory unbase58 = [
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 
            255, 0, 1, 2, 3, 4, 5, 6, 7, 8, 255, 255, 255, 255, 255, 255, 
            255, 9, 10, 11, 12, 13, 14, 15, 16, 255, 17, 18, 19, 20, 21, 255, 
            22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 255, 255, 255, 255, 255,
            255, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 255, 44, 45, 46,
            47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 255, 255, 255, 255, 255
        ];

        uint leadingOnes = countBtcAddressLeadingOnes(prefix, length);

        uint256 prefixValue = 0;
        uint256 prefix1 = 1;
        for (uint i = 0; i < length; i++) {
            uint index = uint(prefix[i]);
            require(index != 255);
            prefixValue = prefixValue * 58 + unbase58[index];
            prefix1 *= 58;
        }

        uint256 top = (uint256(1) << (200 - 8*leadingOnes));
        uint256 total = 0;
        uint256 prefixMin = prefixValue;
        uint256 diff = 0;
        for (uint digits = 1; prefix1/58 < (1 << 192); digits++) {
            prefix1 *= 58;
            prefixMin *= 58;
            prefixValue = prefixValue * 58 + 57;

            diff = 0;
            if (prefixValue >= top) {
                diff += prefixValue - top;
            }
            if (prefixMin < (top >> 8)) {
                diff += (top >> 8) - prefixMin;
            }
            
            if ((58 ** digits) >= diff) {
                total += (58 ** digits) - diff;
            }
        }

        if (prefixMin == 0) { // if prefix is contains only ones: 111111
            total = (58 ** (digits - 1)) - diff;
        }

        return (1 << 192) / total;
    }

    function countBtcAddressLeadingOnes(bytes prefix, uint length) public pure returns(uint) {
        uint leadingOnes = 1;
        for (uint j = 0; j < length && prefix[j] == 49; j++) {
            leadingOnes = j + 1;
        }
        return leadingOnes;
    }

    function requireValidBicoinAddressPrefix(bytes prefixArg) public pure {
        require(prefixArg.length >= 5);
        require(prefixArg[0] == "1" || prefixArg[0] == "3");
        
        for (uint i = 0; i < prefixArg.length; i++) {
            byte ch = prefixArg[i];
            require(ch != "0" && ch != "O" && ch != "I" && ch != "l");
            require((ch >= "1" && ch <= "9") || (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z"));
        }
    }

    function isValidPublicKey(uint256 x, uint256 y) public pure returns(bool) {
        return (mulmod(y, y, m) == addmod(mulmod(x, mulmod(x, x, m), m), 7, m));
    }

}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Main {
    using SafeMath for uint256;
    //using BytesLib for bytes;
    //mapping (address => uint256) public tokens;
    struct Secret {
        string secret;
        string communicate;
        address from;
        
    }
    uint256 numSecrets;
    uint256 lastMined;
    mapping (uint256 => Transaction) transactions;

    struct Block {
        uint256 minedToTransactionN;
        uint256 emission;
        bytes blockHash;
    }
    bytes lastblock
    uint256 numBlocks;
    mapping (uint256 => Block) blocks;
    
    function balanceOf(address _address) public view returns (uint256 balance) {
        return tokens[_address];
    }

    function newTransaction(address _to, uint256 _amount, string _data) public returns (uint256 transactionID) {
        tokens[msg.sender].sub(_amount);
        tokens[msg.sender].add(_to);
        transactionID = numTransactions++;
        _hash = keccak256(msg.sender, _to, _amount, _data);
        transactions[transactionID] = Transaction(_hash, msg.sender, _to, _amount, _data);
        return transactionID;
    }

    function newBlock(uint256 _minedTransactions, string _private) public returns (uint256 howMuch) {
        // ??
    }

    function Main() {
        // create 0 block and 0 transaction
        tokens[msg.sender].add(10);
        newTransaction(msg.sender, 10, '');
    }
}
