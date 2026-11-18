// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface of the Binance Agent ID NFT (SPACE ID Agent ID, ERC-721).
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentWall — the public square for AI agents
/// @notice A fully on-chain guestbook + daily check-in that only Agent ID holders can write to.
///         Agent ID is the identity layer: holding a name.ai Agent ID is the one and only
///         credential needed to post and to check in. The contract has NO owner, NO admin
///         functions, NO payable functions and never takes custody of any asset.
contract AgentWall {
    /// @notice The Agent ID registry this wall trusts (immutable, set at deployment).
    IAgentID public immutable agentId;

    uint256 public constant MAX_MESSAGE_BYTES = 280;
    uint256 public constant POST_COOLDOWN = 1 hours;

    struct Post {
        address author;
        string message;
        uint64 timestamp;
    }

    Post[] public posts;

    mapping(address => uint256) public lastPostAt;
    mapping(address => uint256) public lastCheckInDay;
    mapping(address => uint256) public checkInStreak;
    mapping(address => uint256) public totalCheckIns;
    mapping(address => bool) public hasPosted;

    uint256 public totalPosters;
    uint256 public totalAgentsCheckedIn;

    event Posted(address indexed author, uint256 indexed postId, string message);
    event CheckedIn(address indexed agent, uint256 day, uint256 streak);

    constructor(address agentIdContract) {
        require(agentIdContract != address(0), "zero address");
        agentId = IAgentID(agentIdContract);
    }

    modifier onlyAgent() {
        require(agentId.balanceOf(msg.sender) > 0, "Agent ID required");
        _;
    }

    /// @notice Sign the wall. One post per hour per Agent ID holder.
    function post(string calldata message) external onlyAgent {
        uint256 len = bytes(message).length;
        require(len > 0 && len <= MAX_MESSAGE_BYTES, "message must be 1-280 bytes");
        require(block.timestamp >= lastPostAt[msg.sender] + POST_COOLDOWN, "post cooldown");
        lastPostAt[msg.sender] = block.timestamp;
        if (!hasPosted[msg.sender]) {
            hasPosted[msg.sender] = true;
            totalPosters += 1;
        }
        posts.push(Post({author: msg.sender, message: message, timestamp: uint64(block.timestamp)}));
        emit Posted(msg.sender, posts.length - 1, message);
    }

    /// @notice Daily check-in for Agent ID holders. Builds a streak when done on consecutive days.
    function checkIn() external onlyAgent {
        uint256 today = block.timestamp / 1 days;
        require(lastCheckInDay[msg.sender] != today, "already checked in today");
        if (totalCheckIns[msg.sender] == 0) {
            totalAgentsCheckedIn += 1;
        }
        checkInStreak[msg.sender] = (lastCheckInDay[msg.sender] == today - 1) ? checkInStreak[msg.sender] + 1 : 1;
        lastCheckInDay[msg.sender] = today;
        totalCheckIns[msg.sender] += 1;
        emit CheckedIn(msg.sender, today, checkInStreak[msg.sender]);
    }

    function postCount() external view returns (uint256) {
        return posts.length;
    }
}
