pragma solidity ^0.4.19;


library BytesLib {
    function concat(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bytes) {
        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add 
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function concatStorage(bytes storage _preBytes, bytes memory _postBytes) internal {
        assembly {
            // Read the first 32 bytes of _preBytes storage, which is the length
            // of the array. (We don't need to use the offset into the slot
            // because arrays use the entire slot.)
            let fslot := sload(_preBytes_slot)
            // Arrays of 31 bytes or less have an even value in their slot,
            // while longer arrays have an odd value. The actual length is
            // the slot divided by two for odd values, and the lowest order
            // byte divided by two for even values.
            // If the slot is even, bitwise and the slot with 255 and divide by
            // two to get the length. If the slot is odd, bitwise and the slot
            // with -1 and divide by two.
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)
            let newlength := add(slength, mlength)
            // slength can contain both the length and contents of the array
            // if length < 32 bytes so let's prepare for that
            // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
            switch add(lt(slength, 32), lt(newlength, 32))
            case 2 {
                // Since the new array still fits in the slot, we just need to
                // update the contents of the slot.
                // uint256(bytes_storage) = uint256(bytes_storage) + uint256(bytes_memory) + new_length
                sstore(
                    _preBytes_slot,
                    // all the modifications to the slot are inside this
                    // next block
                    add(
                        // we can just add to the slot contents because the
                        // bytes we want to change are the LSBs
                        fslot,
                        add(
                            mul(
                                div(
                                    // load the bytes from memory
                                    mload(add(_postBytes, 0x20)),
                                    // zero all bytes to the right
                                    exp(0x100, sub(32, mlength))
                                ),
                                // and now shift left the number of bytes to
                                // leave space for the length in the slot
                                exp(0x100, sub(32, newlength))
                            ),
                            // increase length by the double of the memory
                            // bytes length
                            mul(mlength, 2)
                        )
                    )
                )
            }
            case 1 {
                // The stored value fits in the slot, but the combined value
                // will exceed it.
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes_slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes_slot, add(mul(newlength, 2), 1))

                // The contents of the _postBytes array start 32 bytes into
                // the structure. Our first read should obtain the `submod`
                // bytes that can fit into the unused space in the last word
                // of the stored array. To get this, we read 32 bytes starting
                // from `submod`, so the data we read overlaps with the array
                // contents by `submod` bytes. Masking the lowest-order
                // `submod` bytes allows us to add that value directly to the
                // stored value.

                let submod := sub(32, slength)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(
                    sc,
                    add(
                        and(
                            fslot,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
                        ),
                        and(mload(mc), mask)
                    )
                )

                for {
                    mc := add(mc, 0x20)
                    sc := add(sc, 1)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
            default {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes_slot)
                // Start copying to the last used word of the stored array.
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes_slot, add(mul(newlength, 2), 1))

                // Copy over the first `submod` bytes of the new data as in
                // case 1 above.
                let slengthmod := mod(slength, 32)
                let mlengthmod := mod(mlength, 32)
                let submod := sub(32, slengthmod)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(sc, add(sload(sc), and(mload(mc), mask)))
                
                for { 
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
        }
    }

    function slice(bytes _bytes, uint _start, uint _length) internal  pure returns (bytes) {
        require(_bytes.length >= (_start + _length));

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes _bytes, uint _start) internal  pure returns (address) {
        require(_bytes.length >= (_start + 20));
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint(bytes _bytes, uint _start) internal  pure returns (uint256) {
        require(_bytes.length >= (_start + 32));
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

            // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
                // cb is a circuit breaker in the for loop since there's
                //  no said feature for inline assembly loops
                // cb = 1 - don't breaker
                // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                // the next line is the loop condition:
                // while(uint(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                        // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function equalStorage(bytes storage _preBytes, bytes memory _postBytes) internal view returns (bool) {
        bool success = true;

        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes_slot)
            // Decode the length of the stored array like in concatStorage().
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)

            // if lengths don't match the arrays are not equal
            switch eq(slength, mlength)
            case 1 {
                // slength can contain both the length and contents of the array
                // if length < 32 bytes so let's prepare for that
                // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        // blank the last byte which is the length
                        fslot := mul(div(fslot, 0x100), 0x100)

                        if iszero(eq(fslot, mload(add(_postBytes, 0x20)))) {
                            // unsuccess:
                            success := 0
                        }
                    }
                    default {
                        // cb is a circuit breaker in the for loop since there's
                        //  no said feature for inline assembly loops
                        // cb = 1 - don't breaker
                        // cb = 0 - break
                        let cb := 1

                        // get the keccak hash to get the contents of the array
                        mstore(0x0, _preBytes_slot)
                        let sc := keccak256(0x0, 0x20)

                        let mc := add(_postBytes, 0x20)
                        let end := add(mc, mlength)

                        // the next line is the loop condition:
                        // while(uint(mc < end) + cb == 2)
                        for {} eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                // unsuccess:
                                success := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }
}

contract EC {

    uint256 constant gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 constant gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint256 constant n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 constant a = 0;
    uint256 constant b = 7;

    function EC()
    {
    }

    function _jAdd( uint256 x1,uint256 z1,
                    uint256 x2,uint256 z2) constant
        returns(uint256 x3,uint256 z3)
    {
        (x3, z3) = (  addmod( mulmod(z2, x1 , n) ,
                              mulmod(x2, z1 , n),
                              n),
                      mulmod(z1, z2 , n)
                    );
    }

    function _jSub( uint256 x1,uint256 z1,
                    uint256 x2,uint256 z2) constant
        returns(uint256 x3,uint256 z3)
    {
        (x3, z3) = (  addmod( mulmod(z2, x1, n),
                              mulmod(n - x2, z1, n),
                              n),
                      mulmod(z1, z2 , n)
                    );
    }

    function _jMul( uint256 x1,uint256 z1,
                    uint256 x2,uint256 z2) constant
        returns(uint256 x3,uint256 z3)
    {
        (x3, z3) = (  mulmod(x1, x2 , n), mulmod(z1, z2 , n));
    }

    function _jDiv( uint256 x1,uint256 z1,
                    uint256 x2,uint256 z2) constant
        returns(uint256 x3,uint256 z3)
    {
        (x3, z3) = (  mulmod(x1, z2 , n), mulmod(z1 , x2 , n));
    }

    function _inverse( uint256 a) constant
        returns(uint256 invA)
    {
        uint256 t=0;
        uint256 newT=1;
        uint256 r=n;
        uint256 newR=a;
        uint256 q;
        while (newR != 0) {
            q = r / newR;

            (t, newT) = (newT, addmod(t , (n - mulmod(q, newT,n)) , n));
            (r, newR) = (newR, r - q * newR );
        }

        return t;
    }


    function _ecAdd( uint256 x1,uint256 y1,uint256 z1,
                    uint256 x2,uint256 y2,uint256 z2) constant
        returns(uint256 x3,uint256 y3,uint256 z3)
    {
        uint256 l;
        uint256 lz;
        uint256 da;
        uint256 db;

        if ((x1==0)&&(y1==0)) {
            return (x2,y2,z2);
        }

        if ((x2==0)&&(y2==0)) {
            return (x1,y1,z1);
        }

        if ((x1==x2)&&(y1==y2)) {
            (l,lz) = _jMul(x1, z1, x1, z1);
            (l,lz) = _jMul(l, lz, 3, 1);
            (l,lz) = _jAdd(l, lz, a, 1);

            (da,db) = _jMul(y1, z1, 2, 1);
        } else {
            (l,lz) = _jSub(y2, z2, y1, z1);
            (da,db)  = _jSub(x2, z2, x1, z1);
        }

        (l, lz) = _jDiv(l, lz, da, db);


        (x3, da) = _jMul(l, lz, l, lz);
        (x3, da) = _jSub(x3, da, x1, z1);
        (x3, da) = _jSub(x3, da, x2, z2);

        (y3, db) = _jSub(x1, z1, x3, da);
        (y3, db) = _jMul(y3, db, l, lz );
        (y3, db) = _jSub(y3, db, y1, z1 );


        if (da != db) {
            x3 = mulmod(x3, db, n);
            y3 = mulmod(y3, da, n);
            z3 = mulmod(da, db, n);
        } else {
            z3 = da;
        }

    }

    function _ecDouble(uint256 x1,uint256 y1,uint256 z1) constant
        returns(uint256 x3,uint256 y3,uint256 z3)
    {
        (x3,y3,z3) = _ecAdd(x1,y1,z1,x1,y1,z1);
    }



    function _ecMul(uint256 d, uint256 x1,uint256 y1,uint256 z1) constant
        returns(uint256 x3,uint256 y3,uint256 z3)
    {
        uint256 remaining = d;
        uint256 px = x1;
        uint256 py = y1;
        uint256 pz = z1;
        uint256 acx = 0;
        uint256 acy = 0;
        uint256 acz = 1;

        if (d==0) {
            return (0,0,1);
        }

        while (remaining != 0) {
            if ((remaining & 1) != 0) {
                (acx,acy,acz) = _ecAdd(acx,acy,acz, px,py,pz);
            }
            remaining = remaining / 2;
            (px,py,pz) = _ecDouble(px,py,pz);
        }

        (x3,y3,z3) = (acx,acy,acz);
    }

    function publicKey(uint256 privKey) constant
        returns(uint256 qx, uint256 qy)
    {
        uint256 x;
        uint256 y;
        uint256 z;
        (x,y,z) = _ecMul(privKey, gx, gy, 1);
        z = _inverse(z);
        qx = mulmod(x , z ,n);
        qy = mulmod(y , z ,n);
    }

    function deriveKey(uint256 privKey, uint256 pubX, uint256 pubY) constant
        returns(uint256 qx, uint256 qy)
    {
        uint256 x;
        uint256 y;
        uint256 z;
        (x,y,z) = _ecMul(privKey, pubX, pubY, 1);
        z = _inverse(z);
        qx = mulmod(x , z ,n);
        qy = mulmod(y , z ,n);
    }

}

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
    using BytesLib for bytes;
    mapping (address => uint256) public tokens;
    struct Transaction {
        string hash_;
        address from;
        address to;
        uint256 amount;
        string data;
    }
    uint256 numTransactions;
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
