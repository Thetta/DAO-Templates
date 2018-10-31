pragma solidity ^0.4.24;	

contract AddrUintTest {
	struct addrUint {
		address addr;
		uint u;
	}

	mapping(uint => addrUint) public addrUintPairs;

	function addPairs(address[] _addrArray, uint[] _uintArray) public {
		require(_addrArray.length==_uintArray.length);
		for(uint i=0; i<_addrArray.length; i++) {
			addrUintPairs[i] = addrUint(_addrArray[i], _uintArray[i]);
		}
	}
}