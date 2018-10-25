pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

/* 
	Описание
		1. чтобы создать daico, деплоим daicoFactory
		2. любой может создать проект daicoProject, указав при этом stageAmount и stageCount.
		   Какая-то дополнительная инфа указывается? Название, описание, ссылки на пруфы что что-то реализовано, например
		   stageAmount для всех stage одинаковый?
		3. Инвесторы голосуют за то, чтобы вывести некоторый daicoProject на новый stage. Потом закидывают деньги
		4. Инвесторы могут в произвольный момент времени пополнять фонд. 
		   Это как-то учитывать? Это как-то влияет на вес этого инвестора? Может, накидывать им токены 1:1 за их деньги, и давать голосовать по токенам?


	TODO: 
		1. Не набран кворум – сразу стартует повторное голосование (7 дней) с пониженным кворумом >50%
		   Как это сделать? чтобы не влезать в реализацию thetta, можно сделать вызываемую функцию
		2. Кворум набран, но пороговый % проголосовавших «за» не пройден. В результате сразу инициируется голосование по пересмотру роадмапа и доработке проекта через месяц.
		3. Кворум набран, но количество проголосовавших «против» выделения финансирования превысило порог в 80% - средства не выделяются, инициируется процедура голосования за прекращение финансирования проекта, возврат непотраченных средств инвесторам и предусмотренные в отношении недобросовестного проекта санкции


*/

contract Daico is DaoClient {
	mapping(uint => DaicoProject) public projects;
	uint projectsCount;

	bytes32 ACCEPT_NEW_STAGE = keccak256("acceptNewStage");

	constructor(IDaoBase _daoBase) DaoClient(_daoBase) {

	}

	function addNewProject(uint _stagesCount, uint _stageAmount) {
		DaicoProject project = new DaicoProject(_stagesCount, _stageAmount, msg.sender);
		projects[projectsCount] = project;
		projectsCount++;
		return project;
	}

	function addAmountToFund() public payable {}

	function acceptNewStage(uint _projectNum) public isCanDo(ACCEPT_NEW_STAGE) {
		uint amount = projects[_projectNum].stageAmount;
		projects[_projectNum].getAmountForStage.value(amount)();
		projects[_projectNum].goToNextStage();
	}
}