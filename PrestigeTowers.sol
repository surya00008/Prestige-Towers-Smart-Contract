// SPDX-License-Identifier: GPL-3.0
// 10000000000000000000 wei = 10 eth

pragma solidity ^0.8.24;

/**
 * @title PrestigeTowers
 * @notice A real-estate flat booking contract with a 3-phase lifecycle:
 *         Booking -> Voting -> Settled.
 *         Buyers book flats with partial payments during the Booking phase,
 *         then vote on whether the contractor (owner) should receive the funds.
 *         If majority votes in favor, the contractor claims all funds;
 *         otherwise, each buyer can claim a refund.
 */
contract PrestigeTowers {
    address payable public owner; // Contractor / deployer of the contract
    bool private _locked; // Reentrancy guard
    uint public totalFlats; // Total number of flats available for sale
    uint public flatPrice; // Price of each flat (in wei)
    string public projectName; // Name of the real-estate project
    uint public endTime; // Timestamp when the booking phase ends
    uint public totalBuyers; // Count of unique buyers who have booked
    uint public soldFlats; // Number of flats sold so far
    uint public totalVote; // Number of votes cast in favor of contractor
    uint public totalVoteAgainst; // Number of votes cast against contractor
    uint public votingStartTime; // Timestamp when voting phase began
    uint public votingDuration; // Configurable voting duration in seconds
    bool contractFundClaimed; // Whether the contractor has already claimed funds

    enum ProjectState { // explicit project state
        Booking, // booking + deposits
        Voting, // project ended, voting ongoing
        Settled // funds settled
    }

    ProjectState public state;

    struct BuyerDetails {
        address payable buyerAddress;
        uint totalAmountPaid; // Cumulative ETH paid by the buyer
        uint amountRemaining; // How much ETH the buyer still owes
        bool fundClaimed; // Whether the buyer has claimed a refund
    }

    BuyerDetails[] public buyerDetails; //Array to store buyer details
    mapping(address => uint) public buyerMap; // Maps buyer address -> index in buyerDetails[]
    mapping(address => bool) public voted; // Tracks whether a buyer has already voted
    mapping(address => bool) public buyerExists; // buyer existence to be explicit, design principle: Never infer existence from array indices. Track it explicitly. Now contract answers with “Is this address a buyer?”

    event Message(string msg);
    event StateChanged(ProjectState from, ProjectState to);
    event FlatBooked(address indexed buyer, uint amount, uint flatIndex);
    event VoteCast(address indexed voter);
    event VoteCastAgainst(address indexed voter);
    event ContractorClaimed(address indexed contractor, uint amount);
    event BuyerRefunded(address indexed buyer, uint amount);

    /// @param _totalFlats     Number of flats in the project
    /// @param _flatPrice       Price per flat in wei
    /// @param _projectName     Human-readable project name
    /// @param _endTime         Duration (in seconds) from deployment until booking closes
    /// @param _votingDuration  Duration (in seconds) of the voting phase
    constructor(
        uint _totalFlats,
        uint _flatPrice,
        string memory _projectName,
        uint _endTime,
        uint _votingDuration
    ) {
        require(_totalFlats > 0, "Total flats must be > 0");
        require(_flatPrice > 0, "Flat price must be > 0");
        require(_endTime > 0, "End time must be > 0");
        require(_votingDuration > 0, "Voting duration must be > 0");
        owner = payable(msg.sender);
        endTime = block.timestamp + _endTime;
        totalFlats = _totalFlats;
        flatPrice = _flatPrice;
        projectName = _projectName;
        votingDuration = _votingDuration;
        state = ProjectState.Booking;
        buyerDetails.push(); // index 0 reserved — real buyers start at index 1
    }

    /// @notice Returns all buyer records, excluding the dummy entry at index 0.
    function getAllBuyers() external view returns (BuyerDetails[] memory) {
        uint len = buyerDetails.length;
        if (len <= 1) {
            return new BuyerDetails[](0);
        }
        BuyerDetails[] memory buyers = new BuyerDetails[](len - 1);
        for (uint i = 1; i < len; i++) {
            buyers[i - 1] = buyerDetails[i];
        }
        return buyers;
    }

    /// @notice Accept direct ETH transfers (e.g. from selfdestruct or coinbase rewards).
    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    /// @notice Anyone can transition the project from Booking to Voting once the booking deadline has passed.
    function moveToVoting() external {
        require(state == ProjectState.Booking, "Invalid state transition");
        require(block.timestamp >= endTime, "Booking period not ended");

        ProjectState previous = state;
        state = ProjectState.Voting;
        votingStartTime = block.timestamp; // Record when voting begins for duration checks

        emit StateChanged(previous, state);
    }

    /// @notice Allows a non-owner user to book a flat by sending a payment (<= flatPrice).
    ///         Each address can only book one flat.
    function buyFlat() external payable {
        require(state == ProjectState.Booking, "Booking phase ended");
        require(msg.sender != owner, "Owner cannot buy flat");
        require(!buyerExists[msg.sender], "Buyer already exists");
        require(msg.value > 0, "Payment must be greater than zero");
        require(msg.value <= flatPrice, "Exceeds flat price");
        require(soldFlats < totalFlats, "All flats are sold !!");

        BuyerDetails memory buyer = BuyerDetails({
            buyerAddress: payable(msg.sender),
            totalAmountPaid: msg.value,
            amountRemaining: flatPrice - msg.value,
            fundClaimed: false
        });

        soldFlats++;
        totalBuyers++;
        buyerDetails.push(buyer);
        buyerMap[msg.sender] = buyerDetails.length - 1; // Store the buyer's index for quick lookup
        buyerExists[msg.sender] = true;
        emit FlatBooked(msg.sender, msg.value, buyerDetails.length - 1);
    }

    /// @notice Returns the calling buyer's own booking details.
    function getBuyerDetails() external view returns (BuyerDetails memory) {
        require(buyerExists[msg.sender], "Buyer does not exist");

        uint location = buyerMap[msg.sender];
        BuyerDetails memory buyer = buyerDetails[location];

        require(buyer.buyerAddress == msg.sender, "Invalid buyer record");
        return buyer;
    }

    /// @notice Lets an existing buyer deposit additional funds toward their flat price
    ///         during the Booking phase. Cannot overpay beyond amountRemaining.
    function depositFund() external payable {
        require(state == ProjectState.Booking, "Booking phase ended");
        require(msg.sender != owner, "Owner cannot deposit");
        require(buyerExists[msg.sender], "Buyer does not exist");

        uint location = buyerMap[msg.sender];
        BuyerDetails storage buyer = buyerDetails[location]; // `storage` so changes persist on-chain

        require(buyer.buyerAddress == msg.sender, "Invalid buyer record");
        require(buyer.amountRemaining > 0, "Flat already fully paid");
        require(msg.value > 0, "Deposit amount must be greater than zero");
        require(msg.value <= buyer.amountRemaining, "Exceeds remaining amount");

        buyer.totalAmountPaid += msg.value;
        buyer.amountRemaining -= msg.value;

        emit Message("Money deposited");
    }

    /// @notice Returns the total ETH balance held by this contract.
    function getContractBalance() external view returns (uint) {
        return address(this).balance;
    }

    /// @notice Allows a buyer to cast a single vote in favor of the contractor during
    ///         the Voting phase. Each buyer can vote only once.
    function putVote() external {
        require(state == ProjectState.Voting, "Voting phase not active");
        require(
            block.timestamp <= votingStartTime + votingDuration,
            "Voting period ended"
        );
        require(msg.sender != owner, "Owner cannot vote");
        require(buyerExists[msg.sender], "Buyer does not exist");

        uint location = buyerMap[msg.sender];
        require(
            buyerDetails[location].buyerAddress == msg.sender,
            "Invalid buyer"
        );
        require(!voted[msg.sender], "Already voted");

        voted[msg.sender] = true;
        totalVote++;
        emit VoteCast(msg.sender);
    }

    /// @notice Allows a buyer to cast a single vote against the contractor during
    ///         the Voting phase. Each buyer can vote only once.
    function voteAgainst() external {
        require(state == ProjectState.Voting, "Voting phase not active");
        require(
            block.timestamp <= votingStartTime + votingDuration,
            "Voting period ended"
        );
        require(msg.sender != owner, "Owner cannot vote");
        require(buyerExists[msg.sender], "Buyer does not exist");

        uint location = buyerMap[msg.sender];
        require(
            buyerDetails[location].buyerAddress == msg.sender,
            "Invalid buyer"
        );
        require(!voted[msg.sender], "Already voted");

        voted[msg.sender] = true;
        totalVoteAgainst++;
        emit VoteCastAgainst(msg.sender);
    }

    /// @dev Internal helper: automatically moves state from Voting -> Settled
    ///      once the voting duration has elapsed. Called before claim functions
    ///      so the state transition doesn't require a separate transaction.
    function _autoSettleIfNeeded() internal {
        if (
            state == ProjectState.Voting &&
            block.timestamp > votingStartTime + votingDuration
        ) {
            ProjectState previous = state;
            state = ProjectState.Settled;
            emit StateChanged(previous, state);
        }
    }

    /// @notice Contractor claims all contract funds if a majority of buyers voted in favor.
    ///         Can only be called after the voting period has ended and state is Settled.
    function claimFundContractor() public nonReentrant {
        // Voting must be over — no early settlement
        require(
            block.timestamp > votingStartTime + votingDuration,
            "Voting period not ended"
        );
        _autoSettleIfNeeded(); // will move state to Settled if needed
        require(state == ProjectState.Settled, "Project not settled");
        require(msg.sender == owner, "Only contractor");
        require(totalVote > totalVoteAgainst, "Majority does not support");
        require(!contractFundClaimed, "Funds already claimed");

        contractFundClaimed = true;

        // Transfer entire contract balance to the contractor
        uint amount = address(this).balance;
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Contractor ETH transfer failed");

        emit ContractorClaimed(owner, amount);
    }

    /// @notice Allows a buyer to claim a refund of their deposited funds when
    ///         the majority did NOT vote in favor of the contractor.
    ///         Uses checks-effects-interactions pattern to prevent reentrancy:
    ///         balance is zeroed before the external call.
    function claimFundUser() public nonReentrant {
        require(
            block.timestamp > votingStartTime + votingDuration,
            "Voting period not ended"
        );
        _autoSettleIfNeeded(); // CRITICAL FIX: settle state so buyers can claim refunds
        require(state == ProjectState.Settled, "Project not settled");
        require(buyerExists[msg.sender], "Buyer does not exist");
        require(msg.sender != owner, "Owner cannot claim refund");
        require(totalVote <= totalVoteAgainst, "Majority supports contractor");

        uint location = buyerMap[msg.sender];
        BuyerDetails storage buyer = buyerDetails[location];

        require(buyer.buyerAddress == msg.sender, "Invalid buyer");
        require(!buyer.fundClaimed, "Funds already claimed");

        // Checks-effects-interactions: zero balance before sending ETH
        uint amount = buyer.totalAmountPaid;
        buyer.totalAmountPaid = 0;
        buyer.fundClaimed = true;

        (bool success, ) = buyer.buyerAddress.call{value: amount}("");
        require(success, "Refund failed");

        emit BuyerRefunded(msg.sender, amount);
    }
}
