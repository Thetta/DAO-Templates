pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title Daico
 */
contract Daico is Ownable {

	using SafeMath for uint;

	ERC20 public daiToken;
	ERC20 public projectToken;

	address public projectOwner;

	uint public minQuorumRate;
	uint public minVoteRate;
	uint public tapsCount;
	uint public tokenHoldersCount;
	uint[] public tapAmounts;
	uint[] public tapTimestampsFinishAt;

	enum VotingType { ReleaseTap, ReleaseTapDecreasedQuorum, ChangeRoadmap, ChangeRoadmapDecreasedQuorum, TerminateProject, TerminateProjectDecreasedQuorum }
	enum VotingResult { Accept, Decline, QuorumNotReached, NoDecision }

	mapping(uint => mapping(uint => uint)) public tapVotings;
	mapping(uint => uint) public tapVotingsCount;

	mapping(uint => Voting) public votings;
	uint public votingsCount;

	mapping(uint => TapPayment) public tapPayments;

	struct TapPayment {
		uint amount;
		uint createdAt;
		bool isWithdrawn;
	}

	struct Voting {
		uint tapIndex;
		uint yesVotesCount;
		uint noVotesCount;
		uint quorumRate;
		uint createdAt;
		uint finishAt;
		VotingType votingType;
		mapping(address => bool) voted;
	}

	/**
	 * Modifiers
	 */

	/**
	 * Modifier checks that method can be called only by investor / project token holder
	 */
	modifier onlyInvestor() {
		require(projectToken.balanceOf(msg.sender) > 0);
		_;
	}
	
	/**
	 * Modifier checks that tap index exists
	 */
	modifier validTapIndex(uint _tapIndex) {
		require(_tapIndex < tapsCount);
		_;
	}

	/**
	 * Modifier checks that voting index exists
	 */
	modifier validVotingIndex(uint _votingIndex) {
		require(_votingIndex < votingsCount);
		_;
	}

	/**
	 * @dev Contract constructor
	 * @param _daiTokenAddress address of the DAI token contract, project gets payments in DAI tokens
	 * @param _projectTokenAddress project token address, investors hold this token
	 * @param _projectOwnerAddress project owner address who can receive tap payments
	 * @param _tapsCount how many times project should get payments, NOTICE: we can get taps count from _tapAmounts.length but contract deployer can force so that _tapsCount != _tapAmounts.length
	 * @param _tapAmounts array of DAI token amounts in wei that describes how many tokens project gets per single stage
	 * @param _tapTimestampsFinishAt array of deadline timestamps, project should get payment before each deadline timestamp
	 * @param _minQuorumRate min quorum rate, 100 == 100%
	 * @param _minVoteRate min vote rate for proposal to be accepted/declined, 100 == 100%
	 * @param _tokenHoldersCount amount of token holders
	 */
	constructor(
		address _daiTokenAddress,
		address _projectTokenAddress, 
		address _projectOwnerAddress,
		uint _tapsCount, 
		uint[] _tapAmounts, 
		uint[] _tapTimestampsFinishAt, 
		uint _minQuorumRate, 
		uint _minVoteRate,
		uint _tokenHoldersCount
	) public {
		// validation
		require(_daiTokenAddress != address(0));
		require(_projectTokenAddress != address(0));
		require(_projectOwnerAddress != address(0));
		require(_tapsCount > 0);
		require(_tapAmounts.length == _tapsCount);
		require(_tapTimestampsFinishAt.length == _tapsCount);
		require(_minQuorumRate > 0);
		require(_minVoteRate > 0);
		require(_tokenHoldersCount > 0);
		// setting contract properties
		daiToken = ERC20(_daiTokenAddress);
		projectToken = ERC20(_projectTokenAddress);
		projectOwner = _projectOwnerAddress;
		tapsCount = _tapsCount;
		tapAmounts = _tapAmounts;
		tapTimestampsFinishAt = _tapTimestampsFinishAt;
		minQuorumRate = _minQuorumRate;
		minVoteRate = _minVoteRate;
		tokenHoldersCount = _tokenHoldersCount;
		// create initial ReleaseTap votings for all taps
		for(uint i = 0; i < tapsCount; i++) {
			uint createdAt = tapTimestampsFinishAt[i] - 7 days; 
			_createVoting(i, minQuorumRate, createdAt, tapTimestampsFinishAt[i], VotingType.ReleaseTap);
		}
	}
	
	/**
	 * Public methods
	 */

	/**
	 * @dev Returns voting result
	 * @param _votingIndex voting index
	 * @return voting result
	 */
	function getVotingResult(uint _votingIndex) public view validVotingIndex(_votingIndex) returns(VotingResult) {
		Voting memory voting = votings[_votingIndex];
		uint totalVotesCount = voting.yesVotesCount.add(voting.noVotesCount);
		// check whether quorum is reached
		if(totalVotesCount.mul(100) <= tokenHoldersCount.mul(voting.quorumRate)) {
			return VotingResult.QuorumNotReached;
		}
		// check whether voting result is strongly accepted
		if(voting.yesVotesCount.mul(100) >= totalVotesCount.mul(minVoteRate)) {
			return VotingResult.Accept;
		}
		// check whether voting result is strongly declined
		if(voting.noVotesCount.mul(100) >= totalVotesCount.mul(minVoteRate)) {
			return VotingResult.Decline;
		}
		// by default return no decision result
		return VotingResult.NoDecision;
	}

	/**
	 * @dev Checks whether investor already voted in particular voting
	 * @param _votingIndex voting index
	 * @param _investorAddress investor address
	 * @return whether investor has already voted in particular voting
	 */
	function isInvestorVoted(uint _votingIndex, address _investorAddress) external view validVotingIndex(_votingIndex) returns(bool) {
		require(_investorAddress != address(0));
		return votings[_votingIndex].voted[_investorAddress];
	}

	/**
	 * @dev Checks whether project is terminated
	 * @return is project terminated
	 */
	function isProjectTerminated() public view returns(bool) {
		bool isTerminated = false;
		Voting memory latestVoting = votings[votingsCount.sub(1)];
		// if latest voting is of type TerminateProject or TerminateProjectDecreasedQuorum and result Accept then set isTerminated to true
		if(((latestVoting.votingType == VotingType.TerminateProject) || (latestVoting.votingType == VotingType.TerminateProjectDecreasedQuorum)) && (getVotingResult(votingsCount.sub(1)) == VotingResult.Accept)) {
			isTerminated = true;
		}
		return isTerminated;
	}

	/**
	 * @dev Checks whether tap withdraw is accepted by investors for project owner
	 * @param _tapIndex tap index
	 * @return whether withdraw is accepted
	 */
	function isTapWithdrawAcceptedByInvestors(uint _tapIndex) public view validTapIndex(_tapIndex) returns(bool) {
		bool isWithdrawAccepted = false;
		// get latest voting for tap
		uint latestVotingIndex = tapVotings[_tapIndex][tapVotingsCount[_tapIndex].sub(1)];
		Voting memory voting = votings[latestVotingIndex];
		bool isVotingAccepted = getVotingResult(latestVotingIndex) == VotingResult.Accept;
		// if voting is of types: ReleaseTap, ReleaseTapDecreasedQuorum, ChangeRoadmap or ChangeRoadmapDecreasedQuorum then set isWithdrawAccepted to true
		if(((voting.votingType != VotingType.TerminateProject) && (voting.votingType != VotingType.TerminateProjectDecreasedQuorum)) && isVotingAccepted) {
			isWithdrawAccepted = true;
		}
		return isWithdrawAccepted;
	}

	/**
	 * Investor methods
	 */

	/**
	 * @dev Creates a new voting by investor. Investors can create votings of 4 types: ChangeRoadmap, ChangeRoadmapDecreasedQuorum, TerminateProject, TerminateProjectDecreasedQuorum.
	 * @param _tapIndex tap index
	 * @param _votingType voting type
	 */
	function createVotingByInvestor(uint _tapIndex, VotingType _votingType) external onlyInvestor validTapIndex(_tapIndex) {
		// common validation
		require(_votingType == VotingType.ChangeRoadmap || _votingType == VotingType.ChangeRoadmapDecreasedQuorum || _votingType == VotingType.TerminateProject || _votingType == VotingType.TerminateProjectDecreasedQuorum);
		uint latestVotingIndex = tapVotings[_tapIndex][tapVotingsCount[_tapIndex].sub(1)];
		Voting memory latestVoting = votings[latestVotingIndex];
		VotingResult votingResult = getVotingResult(latestVotingIndex);
		// check that last voting is finished
		require(now >= latestVoting.finishAt);

		// if investor wants to create voting of type ChangeRoadmap
		if(_votingType == VotingType.ChangeRoadmap) {
			// check that latest voting is of types ReleaseTap, ReleaseTapDecreasedQuorum, TerminateProject, TerminateProjectDecreasedQuorum
			require(latestVoting.votingType == VotingType.ReleaseTap || latestVoting.votingType == VotingType.ReleaseTapDecreasedQuorum || latestVoting.votingType == VotingType.TerminateProject || latestVoting.votingType == VotingType.TerminateProjectDecreasedQuorum);
			// if latest voting is ReleaseTap
			if(latestVoting.votingType == VotingType.ReleaseTap || latestVoting.votingType == VotingType.ReleaseTapDecreasedQuorum) {
				// check that latest voting result is no decision
				require(votingResult == VotingResult.NoDecision);
			}
			// if latest voting is TerminateProject
			if(latestVoting.votingType == VotingType.TerminateProject || latestVoting.votingType == VotingType.TerminateProjectDecreasedQuorum) {
				// check that latest voting result is decline
				require(votingResult == VotingResult.Decline);
			}
			// create a new voting
			_createVoting(_tapIndex, minQuorumRate, now + 3 weeks, now + 4 weeks, VotingType.ChangeRoadmap);
		}

		// if investor wants to create voting of type ChangeRoadmapDecreasedQuorum
		if(_votingType == VotingType.ChangeRoadmapDecreasedQuorum) {
			// check that latest voting is of type ChangeRoadmap or ChangeRoadmapDecreasedQuorum
			require(latestVoting.votingType == VotingType.ChangeRoadmap || latestVoting.votingType == VotingType.ChangeRoadmapDecreasedQuorum);
			// check that latest voting result has not reached quorum or has no decision
			require((votingResult == VotingResult.QuorumNotReached) || (votingResult == VotingResult.NoDecision));
			// create a new voting
			_createVoting(_tapIndex, 50, now + 3 weeks, now + 4 weeks, VotingType.ChangeRoadmapDecreasedQuorum);
		}

		// if investor wants to create voting of type TerminateProject
		if(_votingType == VotingType.TerminateProject) {
			// check that latest voting is of types: ReleaseTap, ReleaseTapDecreasedQuorum, ChangeRoadmap, ChangeRoadmapDecreasedQuorum
			require(latestVoting.votingType == VotingType.ReleaseTap || latestVoting.votingType == VotingType.ReleaseTapDecreasedQuorum || latestVoting.votingType == VotingType.ChangeRoadmap || latestVoting.votingType == VotingType.ChangeRoadmapDecreasedQuorum);
			// check that latest voting result is decline
			require(votingResult == VotingResult.Decline);
			// create a new voting
			_createVoting(_tapIndex, minQuorumRate, now, now + 2 weeks, VotingType.TerminateProject);
		}

		// if investor wants to create voting of type TerminateProjectDecreasedQuorum
		if(_votingType == VotingType.TerminateProjectDecreasedQuorum) {
			// check that latest voting is of type TerminateProject or TerminateProjectDecreasedQuorum
			require(latestVoting.votingType == VotingType.TerminateProject || latestVoting.votingType == VotingType.TerminateProjectDecreasedQuorum);
			// check that latest voting result has not reached quorum or has no decision
			require((votingResult == VotingResult.QuorumNotReached) || (votingResult == VotingResult.NoDecision));
			// create a new voting
			_createVoting(_tapIndex, 50, now, now + 2 weeks, VotingType.TerminateProjectDecreasedQuorum);
		}
	}
	
	/**
	 * @dev Voting by investor
	 * @param _votingIndex voting index
	 * @param _isYes positive/negative decision
	 */
	function vote(uint _votingIndex, bool _isYes) external onlyInvestor validVotingIndex(_votingIndex) {
		// validation
		require(now >= votings[_votingIndex].createdAt);
		require(now < votings[_votingIndex].finishAt);
		require(!votings[_votingIndex].voted[msg.sender]);
		require(!isProjectTerminated());
		// vote
		votings[_votingIndex].voted[msg.sender] = true;
		if(_isYes) {
			votings[_votingIndex].yesVotesCount = votings[_votingIndex].yesVotesCount.add(1);
		} else {
			votings[_votingIndex].noVotesCount = votings[_votingIndex].noVotesCount.add(1);
		}
	}

	/**
	 * Evercity member / owner methods
	 */

	/**
	 * @dev Creates a new voting by owner. Owner can create votings only of type ReleaseTapDecreasedQuorum
	 * @param _tapIndex tap index
	 * @param _votingType voting type
	 */
	function createVotingByOwner(uint _tapIndex, VotingType _votingType) external onlyOwner validTapIndex(_tapIndex) {
		// validation
		require(_votingType == VotingType.ReleaseTapDecreasedQuorum);
		uint latestVotingIndex = tapVotings[_tapIndex][tapVotingsCount[_tapIndex].sub(1)];
		Voting memory latestVoting = votings[latestVotingIndex];
		// check that latest voting is finished
		require(now >= latestVoting.finishAt);
		// check that latest voting is of type ReleaseTap or ReleaseTapDecreasedQuorum
		require(latestVoting.votingType == VotingType.ReleaseTap || latestVoting.votingType == VotingType.ReleaseTapDecreasedQuorum);
		// check that latest voting result is quorum not reached
		require(getVotingResult(latestVotingIndex) == VotingResult.QuorumNotReached);
		// create a new voting
		_createVoting(_tapIndex, 50, now, now + 7 days, VotingType.ReleaseTapDecreasedQuorum);
	}

	/**
	 * @dev Withdraws DAI tokens in case project is terminated
	 */
	function withdrawFunding() external onlyOwner {
		// validation
		require(isProjectTerminated());
		// calculate amount of DAI tokens to withdraw
		uint amountToWithdraw = 0;
		for(uint i = 0; i < tapsCount; i++) {
			if(!tapPayments[i].isWithdrawn) {
				amountToWithdraw = amountToWithdraw.add(tapAmounts[i]);
			}
		}
		// transfer DAI tokens to owner
		daiToken.transfer(owner, amountToWithdraw);
	}

	/**
	 * Project owner methods
	 */

	/**
	 * @dev Withdraws tap payment by project owner
	 * @param _tapIndex tap index
	 */
	function withdrawTapPayment(uint _tapIndex) external validTapIndex(_tapIndex) {
		// validation
		require(msg.sender == projectOwner);
		require(isTapWithdrawAcceptedByInvestors(_tapIndex));
		require(!tapPayments[_tapIndex].isWithdrawn);
		// create tap payment
		TapPayment memory tapPayment;
		tapPayment.amount = tapAmounts[_tapIndex];
		tapPayment.createdAt = now;
		tapPayment.isWithdrawn = true;
		tapPayments[_tapIndex] = tapPayment;
		// transfer DAI tokens for selected tap to project owner
		daiToken.transfer(projectOwner, tapAmounts[_tapIndex]);
	}

	/**
	 * Internal methods
	 */

	/**
	 * @dev Creates a new voting
	 * @param _tapIndex tap index
	 * @param _quorumRate quorum rate
	 * @param _createdAt when voting was created timestamp
	 * @param _finishAt when voting should be finished timestamp
	 * @param _votingType voting type
	 */
	function _createVoting(uint _tapIndex, uint _quorumRate, uint _createdAt, uint _finishAt, VotingType _votingType) internal validTapIndex(_tapIndex) {
		// validation
		require(_quorumRate > 0);
		require(_createdAt > 0);
		require(_finishAt > 0);
		// create a new voting
		Voting memory voting;
		voting.tapIndex = _tapIndex;
		voting.quorumRate = _quorumRate;
		voting.createdAt = _createdAt;
		voting.finishAt = _finishAt;
		voting.votingType = _votingType;
		votings[votingsCount] = voting;
		// update contract properties
		tapVotings[_tapIndex][tapVotingsCount[_tapIndex]] = votingsCount;
		tapVotingsCount[_tapIndex] = tapVotingsCount[_tapIndex].add(1);
		votingsCount = votingsCount.add(1);
	}

}
