// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EthGrow DAO
 * @dev A decentralized autonomous organization for community-driven decision making
 * @notice This contract implements governance, proposal management, and treasury operations
 */
contract EthGrowDAO {
    
    // Structs
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
    
    // State variables
    address public founder;
    string public daoName;
    uint256 public memberCount;
    uint256 public proposalCount;
    uint256 public treasuryBalance;
    uint256 public minimumQuorum;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    bool private locked;
    
    // Constants
    uint256 public constant MEMBERSHIP_FEE = 0.1 ether;
    uint256 public constant BASE_VOTING_POWER = 1;
    uint256 public constant REPUTATION_MULTIPLIER = 10;
    
    // Mappings
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public isBlacklisted;
    
    // Arrays
    address[] public memberAddresses;
    uint256[] public activeProposalIds;
    
    // Events
    event MemberJoined(address indexed member, uint256 timestamp);
    event MemberLeft(address indexed member, uint256 timestamp);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 amount,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(
        uint256 indexed proposalId,
        bool success,
        uint256 amount
    );
    event FundsDeposited(address indexed from, uint256 amount);
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);
    event MemberBlacklisted(address indexed member);
    event ReputationAwarded(address indexed member, uint256 amount);
    
    // Modifiers
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
    
    /**
     * @dev Constructor initializes the DAO with founder and basic parameters
     * @param _daoName The name of the DAO
     */
    constructor(string memory _daoName) {
        founder = msg.sender;
        daoName = _daoName;
        minimumQuorum = 51; // 51% quorum requirement
        votingPeriod = 7 days;
        proposalThreshold = 0.01 ether;
        
        // Founder automatically becomes first member
        members[founder] = Member({
            isActive: true,
            joinedAt: block.timestamp,
            votingPower: BASE_VOTING_POWER * 10, // Founder gets 10x voting power
            reputation: 100,
            proposalsCreated: 0,
            votesParticipated: 0
        });
        
        memberAddresses.push(founder);
        memberCount = 1;
    }
    
    /**
     * @dev Allows users to join the DAO by paying membership fee
     */
    function joinDAO() external payable noReentrant {
        require(!members[msg.sender].isActive, "EthGrow: Already a member");
        require(!isBlacklisted[msg.sender], "EthGrow: Address is blacklisted");
        require(msg.value >= MEMBERSHIP_FEE, "EthGrow: Insufficient membership fee");
        
        members[msg.sender] = Member({
            isActive: true,
            joinedAt: block.timestamp,
            votingPower: BASE_VOTING_POWER,
            reputation: 10,
            proposalsCreated: 0,
            votesParticipated: 0
        });
        
        memberAddresses.push(msg.sender);
        memberCount++;
        treasuryBalance += msg.value;
        
        emit MemberJoined(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Allows members to leave the DAO
     */
    function leaveDAO() external onlyMember noReentrant {
        members[msg.sender].isActive = false;
        memberCount--;
        
        emit MemberLeft(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Creates a new proposal for the DAO to vote on
     * @param title The title of the proposal
     * @param description Detailed description of the proposal
     * @param amount The amount of ETH requested (if applicable)
     * @param recipient The address to receive funds (if applicable)
     */
    function createProposal(
        string memory title,
        string memory description,
        uint256 amount,
        address payable recipient
    ) external onlyMember returns (uint256) {
        require(bytes(title).length > 0, "EthGrow: Title cannot be empty");
        require(bytes(description).length > 0, "EthGrow: Description cannot be empty");
        require(amount <= address(this).balance, "EthGrow: Insufficient treasury funds");
        
        if (amount > proposalThreshold) {
            require(
                members[msg.sender].reputation >= 50,
                "EthGrow: Insufficient reputation for large proposals"
            );
        }
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.amount = amount;
        newProposal.recipient = recipient;
        newProposal.votesFor = 0;
        newProposal.votesAgainst = 0;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;
        newProposal.executed = false;
        newProposal.exists = true;
        
        activeProposalIds.push(proposalId);
        members[msg.sender].proposalsCreated++;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            amount,
            newProposal.endTime
        );
        
        return proposalId;
    }
    
    /**
     * @dev Allows members to vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) 
        external 
        onlyMember 
        proposalExists(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp < proposal.endTime, "EthGrow: Voting period ended");
        require(!proposal.executed, "EthGrow: Proposal already executed");
        require(!proposal.hasVoted[msg.sender], "EthGrow: Already voted");
        
        Member storage member = members[msg.sender];
        uint256 voteWeight = member.votingPower + (member.reputation / REPUTATION_MULTIPLIER);
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteWeight[msg.sender] = voteWeight;
        
        if (support) {
            proposal.votesFor += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }
        
        member.votesParticipated++;
        member.reputation += 1; // Award reputation for voting
        
        emit VoteCast(proposalId, msg.sender, support, voteWeight);
    }
    
    /**
     * @dev Executes a proposal if it has passed
     * @param proposalId The ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) 
        external 
        proposalExists(proposalId) 
        noReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.endTime, "EthGrow: Voting period not ended");
        require(!proposal.executed, "EthGrow: Proposal already executed");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 totalPossibleVotes = getTotalVotingPower();
        
        require(
            (totalVotes * 100) / totalPossibleVotes >= minimumQuorum,
            "EthGrow: Quorum not reached"
        );
        
        proposal.executed = true;
        bool success = false;
        
        if (proposal.votesFor > proposal.votesAgainst) {
            if (proposal.amount > 0 && proposal.recipient != address(0)) {
                require(
                    address(this).balance >= proposal.amount,
                    "EthGrow: Insufficient contract balance"
                );
                
                (bool sent, ) = proposal.recipient.call{value: proposal.amount}("");
                require(sent, "EthGrow: Failed to send Ether");
                
                treasuryBalance -= proposal.amount;
                success = true;
                
                // Award reputation to proposer for successful proposal
                members[proposal.proposer].reputation += 5;
            } else {
                success = true;
            }
        }
        
        emit ProposalExecuted(proposalId, success, proposal.amount);
    }
    
    /**
     * @dev Returns the total voting power of all active members
     * @return Total voting power
     */
    function getTotalVotingPower() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (members[memberAddresses[i]].isActive) {
                Member memory member = members[memberAddresses[i]];
                total += member.votingPower + (member.reputation / REPUTATION_MULTIPLIER);
            }
        }
        return total;
    }
    
    /**
     * @dev Returns proposal details
     * @param proposalId The ID of the proposal
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId)
        returns (
            address proposer,
            string memory title,
            string memory description,
            uint256 amount,
            address recipient,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 endTime,
            bool executed
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.amount,
            proposal.recipient,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.endTime,
            proposal.executed
        );
    }
    
    /**
     * @dev Checks if an address has voted on a proposal
     * @param proposalId The proposal ID
     * @param voter The voter address
     * @return True if voted, false otherwise
     */
    function hasVoted(uint256 proposalId, address voter) 
        external 
        view 
        proposalExists(proposalId)
        returns (bool) 
    {
        return proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Returns member statistics
     * @param memberAddress The member's address
     */
    function getMemberStats(address memberAddress) 
        external 
        view 
        returns (
            bool isActive,
            uint256 joinedAt,
            uint256 votingPower,
            uint256 reputation,
            uint256 proposalsCreated,
            uint256 votesParticipated
        )
    {
        Member memory member = members[memberAddress];
        return (
            member.isActive,
            member.joinedAt,
            member.votingPower,
            member.reputation,
            member.proposalsCreated,
            member.votesParticipated
        );
    }
    
    /**
     * @dev Allows founder to update quorum percentage
     * @param newQuorum New quorum percentage (1-100)
     */
    function updateQuorum(uint256 newQuorum) external onlyFounder {
        require(newQuorum > 0 && newQuorum <= 100, "EthGrow: Invalid quorum");
        uint256 oldQuorum = minimumQuorum;
        minimumQuorum = newQuorum;
        emit QuorumUpdated(oldQuorum, newQuorum);
    }
    
    /**
     * @dev Allows founder to blacklist malicious members
     * @param member The address to blacklist
     */
    function blacklistMember(address member) external onlyFounder {
        require(member != founder, "EthGrow: Cannot blacklist founder");
        isBlacklisted[member] = true;
        if (members[member].isActive) {
            members[member].isActive = false;
            memberCount--;
        }
        emit MemberBlacklisted(member);
    }
    
    /**
     * @dev Allows founder to award reputation to members
     * @param member The member address
     * @param amount Reputation points to award
     */
    function awardReputation(address member, uint256 amount) external onlyFounder {
        require(members[member].isActive, "EthGrow: Not an active member");
        members[member].reputation += amount;
        emit ReputationAwarded(member, amount);
    }
    
    /**
     * @dev Allows anyone to deposit funds to the DAO treasury
     */
    function depositToTreasury() external payable {
        require(msg.value > 0, "EthGrow: Must send some Ether");
        treasuryBalance += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Returns the number of active proposals
     * @return Number of active proposals
     */
    function getActiveProposalCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeProposalIds.length; i++) {
            uint256 id = activeProposalIds[i];
            if (!proposals[id].executed && block.timestamp < proposals[id].endTime) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Returns list of all member addresses
     * @return Array of member addresses
     */
    function getAllMembers() external view returns (address[] memory) {
        return memberAddresses;
    }
    
    /**
     * @dev Returns the DAO's current treasury balance
     * @return Treasury balance in wei
     */
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Fallback function to receive Ether
     */
    receive() external payable {
        treasuryBalance += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
}
