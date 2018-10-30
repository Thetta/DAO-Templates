pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "./DaicoProject.sol";

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
		   1.1. Как это сделать? чтобы не влезать в реализацию thetta, можно сделать вызываемую функцию
		   1.2. Функцию start

		2. Кворум набран, но пороговый % проголосовавших «за» не пройден. В результате сразу инициируется голосование по пересмотру роадмапа и доработке проекта через месяц.
		   Есть два варианта –
		    2.1. Проект создается заново, перезаливается
		    2.2. У проекта изменяется схема. Но для этого нужно будет удалять children'ов у splitter, а у нас такой функции нет.
		    2.3. Можно сделать схему без splitter'а, и некоторый mapping будет говорить, какой expense/fund на каком месте стоит.
		3. Кворум набран, но количество проголосовавших «против» выделения финансирования превысило порог в 80% - средства не выделяются, инициируется процедура голосования за прекращение финансирования проекта, возврат непотраченных средств инвесторам и предусмотренные в отношении недобросовестного проекта санкции
		   3.1. Какого рода санкции? Как-то это формализуется? Если нет, то и никаких санцкий нет, только пожурить
		   3.2. Как мы прекращаем финансирование, возврат непотраченых средств? Как только проект получит возможность снять все деньги определенного транша, он их все снимет, нечего будет забирать.
		        Или мы хотим, чтобы каждый вывод средств был под какую-то определенную цель, и чтобы инвесторы это одобряли? Очень много бюрократии и мало защиты.
		   3.3. Зачем процедура голосования за прекращение финансирования, если на следующий stage проект все равно не получает деньги? Можно, например, просто уничтожать контракт проекта.
*/


contract Daico is DaoClient {
	mapping(uint => DaicoProject) public projects;
	uint projectsCount;
	address[] public investors;

	bytes32 ACCEPT_NEW_STAGE = keccak256("acceptNewStage");
	bytes32 ACCEPT_NEW_STAGE_LESS_QUORUM = keccak256("acceptNewStage");

	modifier previousVotingQuorumNotReached(uint _projectNum) {
		_;
	}

	constructor(IDaoBase _daoBase, address[] _investors) DaoClient(_daoBase) {
		investors = _investors;
	}

	function addNewProject(uint _stagesCount, uint _stageAmount) {
		DaicoProject project = new DaicoProject(_stagesCount, _stageAmount, msg.sender, address(this));
		projects[projectsCount] = project;
		projectsCount++;
		// return project;
	}

	function addAmountToFund() public payable {}

	function goToNewStage(uint _projectNum) public isCanDo(ACCEPT_NEW_STAGE) {
		uint amount = projects[_projectNum].stageAmount();
		projects[_projectNum].getAmountForStage.value(amount)();
		projects[_projectNum].goToNextStage();
	}


	function goToNewStageLessQuorum(uint _projectNum) public 
		previousVotingQuorumNotReached(_projectNum) 
		isCanDo(ACCEPT_NEW_STAGE_LESS_QUORUM) 
	{
		require(msg.sender == projects[_projectNum].projectOwner());
		// TODO: require quorum is not reached
		DaicoProject.ProjectState projectState = DaicoProject.ProjectState.Basic;

		projects[_projectNum].setProjectState(projectState);

		// TODO: как выставить уменьшенный кворум именно для этого голосования? 
		//       никак, нужно сделать другое голосование с другими параметрами
	}


}