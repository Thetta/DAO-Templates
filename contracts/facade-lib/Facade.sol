pragma solidity ^0.4.24;

contract Facade {
	address lib;
	address store;

	function do(string _func, bytes32[] _params) returns(bytes32) {
		lib.do();
	}

	function get(string _recordName) public returns(bytes32) {
		store.call
	}

	function set(string _recordName, bytes32 _newRecordValue) public {
		store.call
	}	

	function setLib(address _newLib) {
		lib = _newLib;
	}

	function setStore(address _newStore) {
		store = _newStore;
	}
}