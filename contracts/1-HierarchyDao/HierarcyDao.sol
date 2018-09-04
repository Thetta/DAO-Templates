pragma solidity ^0.4.24;
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/DaoClient.sol";

contract HierarchyDao is DaoClient {
	constructor(IDaoBase _daoBase)public DaoClient(_daoBase){
	}
}
