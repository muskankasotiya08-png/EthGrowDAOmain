// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Structs {
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool exists;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voteWeight;
    }

    struct Member {
        bool isActive;
        uint256 joinedAt;
        uint256 votingPower;
        uint256 reputation;
        uint256 proposalsCreated;
        uint256 votesParticipated;
    }

    uint256 public constant MEMBERSHIP_FEE = 0.1 ether;
    uint256 public constant BASE_VOTING_POWER = 1;
    uint256 public constant REPUTATION_MULTIPLIER = 10;

    address public founder;
    string public daoName;
    uint256 public minimumQuorum;
    uint256 public treasuryBalance;
    bool public locked;

    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public isBlacklisted;

    address[] public memberAddresses;
    uint256[] public activeProposalIds;

    modifier onlyFounder() {
        require(msg.sender == founder, "EthGrow: Caller is not the founder");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "EthGrow: Caller is not a member");
        require(!isBlacklisted[msg.sender], "EthGrow: Member is blacklisted");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposals[proposalId].exists, "EthGrow: Proposal does not exist");
        _;
    }

    modifier noReentrant() {
        require(!locked, "EthGrow: Reentrant call detected");
        locked = true;
        _;
        locked = false;
    }

    constructor(string memory _daoName) {
        founder = msg.sender;
        daoName = _daoName;
        minimumQuorum = 51;
        members[founder] = Member({
            isActive: true,
            joinedAt: block.timestamp,
            votingPower: BASE_VOTING_POWER * 10,
            reputation: 0,
            proposalsCreated: 0,
            votesParticipated: 0
        });
        memberAddresses.push(founder);
    }
}
