pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";


// DaicoProject is funds owner
contract DaicoProject {

	mapping(uint => WeiAbsoluteExpense) stages;
	uint stageAmount;
	uint stagesCount;
	address projectOwner;
	address daicoAddress;
	uint currentStage = 0;
	ProjectState projectState = ProjectState.Basic;

	enum ProjectState {
		Basic,
		VotingWithA50Quorum,
		ChangesNeeded,
		Rejected
	}

	modifier onlyDaico() {
		require(msg.sender==_daicoAddress);
		_;
	}

	modifier onlyProjectOwner() {
		require(msg.sender==_projectOwner);
		_;
	}

	constructor(uint _stagesCount, uint _stageAmount, address _projectOwner, address _daicoAddress) {
		stageAmount = _stageAmount;
		stagesCount = _stagesCount;
		projectOwner = _projectOwner;
		daicoAddress = _daicoAddress;

		for(uint i=0; i++; i<_stagesCount) {
			WeiAbsoluteExpense stage = new WeiAbsoluteExpense(_stageAmount);
			if(i!=0) {
				stage.Close();
			}

			splitter.addChild(IWeiReceiver(stage));
			stages[i] = stage;
		}
	}

	function flushFundsFromStage(uint _stageNum) onlyProjectOwner {
		stages[_stageNum].flushTo(_projectOwner);
	}

	function goToNextStage() onlyDaico {
		require(currentStage<stagesCount);
		currentStage++;
		stages[currentStage].Open();
	}

	function getAmountForStage() public payable onlyDaico {
		stages[currentStage].processFunds.value(msg.value)(msg.value);		
	}

	function setProjectState(ProjectState _state) public onlyDaico {
		projectState = _state;
	}
}