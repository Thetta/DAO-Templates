pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title IDaico
 * How it works:
 * 1. Evercity member deploys current contract for some project.
 * 2. Evercity member allows to deplyed contract to transfer some amount of DAI tokens.
 *
 * Scenarios:
 * # Successful voting for tap release
 * 1. Evercity member creates a new voting of type 'ReleaseTap' via 'createVotingByOwner()'.
 * 2. Token holders votes via 'vote()'.
 * 3. Quorum reached with positive decision.
 * 4. Project owner withdraws DAI tokens for accepted tap via 'withdrawTapPayment()'.
 *
 * # Quorum not reached for 'ReleaseTap' voting
 * 1. Evercity member creates a new voting of type 'ReleaseTap' via 'createVotingByOwner()'.
 * 2. Token holders votes via 'vote()'.
 * 3. Quorum NOT reached.
 * 4. Evercity member creates a new voting of type 'ReleaseTapDecreasedQuorum' via 'createVotingByOwner()'.
 * 5. Quorum reached with positive decision.
 * 6. Project owner withdraws DAI tokens for accepted tap via 'withdrawTapPayment()'.
 *
 * # Quorum reached but minVoteRate with positive decisions is not reached
 * 1. Evercity member creates a new voting of type 'ReleaseTap' via 'createVotingByOwner()'.
 * 2. Token holders votes via 'vote()'.
 * 3. Quorum reached but minVoteRate with positive decisions is not reached
 * 4. One of the investors creates a new voting of type 'ChangeRoadmap' via 'createVotingByInvestor()'.
 * 5. Quorum reached with positive decision.
 * 6. Project owner withdraws DAI tokens for accepted tap via 'withdrawTapPayment()'.
 *
 * # Voting strongly against tap release
 * 1. Evercity member creates a new voting of type 'ReleaseTap' via 'createVotingByOwner()'.
 * 2. Token holders votes via 'vote()'.
 * 3. Quorum reached and more than minVoteRate token holders voted against tap release.
 * 4. One of the investors creates a new voting of type 'TerminateProject' via 'createVotingByInvestor()'.
 * 5. Quorum reached with positive decision. Contract property 'isTerminated' is set to true.
 * 6. Evercity member withdraws left DAI tokens via 'withdrawFunding()'.
 */
contract IDaico is Ownable {

	ERC20 public daiToken;
	ERC20 public projectToken;

	address public projectOwner;

	bool public isTerminated;

	uint public minQuorumRate;
	uint public minVoteRate;
	uint public tapsCount;
	uint public tokenHoldersCount;
	uint[] public tapAmounts;
	uint[] public tapTimestampsFinishAt;

	enum VotingType { ReleaseTap, ReleaseTapDecreasedQuorum, ChangeRoadmap, TerminateProject }
	enum VotingResult { Ok, QuorumNotReached }

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
	 * @dev Returns voting result for voting
	 * @param _votingIndex voting index
	 * @return voting result
	 */
	function getVotingResult(uint _votingIndex) public returns(VotingResult);

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
	 * @param _votingIndex voting index
	 * @param _decision decision, yes or no
	 */
	function vote(uint _votingIndex, bool _decision) external;

	/**
	 * Owner / evercity member methods
	 */

	/**
	 * @dev Creates a new voting by owner. Owner can create 2 types of votings: tap release and tap release with decreased quorum rate
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
	 * @param _votingType voting type
	 * @param _quorumRate quorum rate
	 */
	function _createVoting(uint _tapIndex, VotingType _votingType, uint _quorumRate) internal;

}
