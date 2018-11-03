pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "@thetta/core/contracts/moneyflow/ether/WeiAbsoluteExpense.sol";

// DaicoProject is funds owner
contract DaicoProject {
	mapping(uint => WeiAbsoluteExpense) stages;
	uint public stageAmount;
	uint public stagesCount;
	address public projectOwner;
	address public daicoAddress;
	uint public currentStage = 0;

	uint public blockUntil = 0;
	bool public isRemoved = false;

	modifier onlyDaico() {
		require(msg.sender==daicoAddress);
		_;
	}

	modifier onlyProjectOwner() {
		require(msg.sender==projectOwner);
		_;
	}

	constructor(uint _stagesCount, uint _stageAmount, address _projectOwner, address _daicoAddress) {
		stageAmount = _stageAmount;
		stagesCount = _stagesCount;
		projectOwner = _projectOwner;
		daicoAddress = _daicoAddress;

		for(uint i=0; i<_stagesCount; i++) {
			WeiAbsoluteExpense stage = new WeiAbsoluteExpense(_stageAmount);
			
			stages[i] = stage;
		}
	}

	function flushFundsFromStage(uint _stageNum) onlyProjectOwner {
		stages[_stageNum].flushTo(projectOwner);
	}

	function goToNextStage() onlyDaico {
		require(currentStage<stagesCount);
		currentStage++;
	}

	function getAmountForStage() public payable onlyDaico {
		stages[currentStage].processFunds.value(msg.value)(msg.value);		
	}

	function setBlock(uint _blockUntil) public onlyDaico {
		blockUntil = _blockUntil;
	}

	function removeProject() public onlyDaico {
		isRemoved = true;
	}	
}