pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title IDaico
 * How it works:
 * 1. Evercity member deploys current contract for some project.
 * 2. Contract creates initial votings of type ReleaseTap for each tap.
 * 3. Evercity member transfers DAI tokens to DAICO contract address.
 *
 * Scenarios:
 * # Successful voting for tap release
 * 1. Token holders votes via 'vote()'.
 * 2. Quorum reached with positive decision.
 * 3. Project owner withdraws DAI tokens for accepted tap via 'withdrawTapPayment()'.

 * # Quorum not reached for 'ReleaseTap' voting
 * 1. Token holders votes via 'vote()'.
 * 2. Quorum NOT reached.
 * 3. Evercity member creates a new voting of type 'ReleaseTapDecreasedQuorum' via 'createVotingByOwner()'.
 * 4. Quorum reached with positive decision.
 * 5. Project owner withdraws DAI tokens for accepted tap via 'withdrawTapPayment()'.
 *
 * # Quorum reached but minVoteRate with positive decisions is not reached
 * 1. Token holders votes via 'vote()'.
 * 2. Quorum reached but minVoteRate with positive decisions is not reached
 * 3. One of the investors creates a new voting of type 'ChangeRoadmap' via 'createVotingByInvestor()'.
 * 4. Quorum reached with positive decision.
 * 5. Project owner withdraws DAI tokens for accepted tap via 'withdrawTapPayment()'.
 *
 * # Voting strongly against tap release
 * 1. Token holders votes via 'vote()'.
 * 2. Quorum reached and more than minVoteRate token holders voted against tap release.
 * 3. One of the investors creates a new voting of type 'TerminateProject' via 'createVotingByInvestor()'.
 * 4. Quorum reached with positive decision.
 * 5. Evercity member withdraws left DAI tokens via 'withdrawFunding()'.
 */
contract IDaico is Ownable {

	ERC20 public daiToken;
	ERC20 public projectToken;

	address public projectOwner;

	uint public minQuorumRate;
	uint public minVoteRate;
	uint public tapsCount;
	uint public tokenHoldersCount;
	uint[] public tapAmounts;
	uint[] public tapTimestampsFinishAt;

	enum VotingType { ReleaseTap, ReleaseTapDecreasedQuorum, ChangeRoadmap, TerminateProject }
	enum VotingResult { Accept, Decline, QuorumNotReached, NoDecision }

	mapping(uint => mapping(uint => uint)) public tapVotings;
	mapping(uint => uint) public tapVotingsCount;

	mapping(uint => Voting) public votings;
	uint public votingsCount;

	mapping(uint => TapPayment) public tapPayments;
	uint public tapPaymentsCount;

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
	) public {}

	/**
	 * Public methods
	 */

	/**
	 * @dev Returns voting result for voting.
	 * There are 4 voting results:
	 * - Accept: proposal accepted, majority of investors said 'yes'
	 * - Decline: proposal declined, majority of investors said 'no'
	 * - QuorumNotReached: not enough investors voted
	 * - NoDecision: no consensus among investors, ex: 50% of 'yes' vs 50% of 'no' votes
	 * @param _votingIndex voting index
	 * @return voting result
	 */
	function getVotingResult(uint _votingIndex) public view returns(VotingResult);

	/**
	 * @dev Checks whether project is terminated. 
	 * Project is terminated when the last voting is of type TerminateProject with Accept result.
	 * When project is terminated contract owner(evercity member) can withdraw DAI tokens via 'withdrawFunding()'.
	 * @return is project terminated
	 */
	function isProjectTerminated() public view returns(bool);

	/**
	 * @dev Checks whether tap withdraw is accepted by investors for project owner
	 * @param _tapIndex tap index
	 * @return whether withdraw is accepted
	 */
	function isTapWithdrawAcceptedByInvestors(uint _tapIndex) public view returns(bool);

	/**
	 * Investor methods
	 */

	/**
	 * @dev Creates a new voting by investor. Investor can create 2 types of votings: change roadmap and terminate project
	 * @param _tapIndex tap index
	 * @param _votingType voting type
	 */
	function createVotingByInvestor(uint _tapIndex, VotingType _votingType) external;

	/**
	 * @dev Vote method for token holder
	 * Preconditions:
	 * - Is token holder(has at least 1 project token)
	 * - Valid voting index
	 * - Is valid voting period
	 * - Investor hasn't voted earlier for this proposal
	 * @param _votingIndex voting index
	 * @param _isYes decision, yes or no
	 */
	function vote(uint _votingIndex, bool _isYes) external;

	/**
	 * Owner / evercity member methods
	 */

	/**
	 * @dev Creates a new voting by owner. Owner can create 1 type of votings: tap release with decreased quorum rate
	 * @param _tapIndex tap index
	 * @param _votingType voting type
	 */
	function createVotingByOwner(uint _tapIndex, VotingType _votingType) external;

	/**
	 * @dev Withdraws all left DAI tokens to owner address
	 * Preconditions:
	 * - contract is terminated in case of successful TerminateProject voting
	 */
	function withdrawFunding() external;

	/**
	 * Project owner methods
	 */

	/**
	 * @dev Withdraws tap payment by project owner 
	 * Preconditions:
	 * - Valid tap index
	 * - Tap is not yet withdrawn
	 * - Tap withdrawal is accepted by investors
	 * @param _tapIndex tap index
	 * Result: DAI tokens for current tap are transfered to project owner address
	 */
	function withdrawTapPayment(uint _tapIndex) external;

	/**
	 * Internal methods
	 */

	/**
	 * @dev Creates a new voting for tap
	 * @param _tapIndex tap index
	 * @param _quorumRate quorum rate
	 * @param _createdAt when voting was created timestamp
	 * @param _finishAt when voting should be finished timestamp
	 * @param _votingType voting type
	 */
	function _createVoting(uint _tapIndex, uint _quorumRate, uint _createdAt, uint _finishAt, VotingType _votingType) internal;

}
