pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";


// DaicoProject is funds owner
contract DaicoProject {

	mapping(uint => OneTimeFund) stages;
	WeiTopdownSplitter splitter;
	uint stageAmount;
	uint stagesCount;
	address projectOwner;
	address daicoAddress;
	uint currentStage = 0;

	constructor(uint _stagesCount, uint _stageAmount, address _projectOwner, address _daicoAddress) {
		stageAmount = _stageAmount;
		stagesCount = _stagesCount;
		projectOwner = _projectOwner;
		daicoAddress = _daicoAddress;

		WeiTopdownSplitter splitter = new WeiTopdownSplitter();

		for(uint i=0; i++; i<_stagesCount) {
			OneTimeFund stage = new OneTimeFund(_stageAmount);
			if(i!=0) {
				stage.Close();
			}

			splitter.addChild(IWeiReceiver(stage));
			stages[i] = stage;
		}
	}

	function flushFundsFromStage(uint _stageNum) {
		require(msg.sender==_projectOwner);
		stages[_stageNum].flushTo(_projectOwner);
	}

	function goToNextStage() {
		require(msg.sender==_daicoAddress);
		require(currentStage<stagesCount);
		currentStage++;
		stages[currentStage].Open();
	}

	function getAmountForStage() public payable {
		require(msg.sender==_daicoAddress);
		splitter.processFunds.value(msg.value)(msg.value);
	}
}