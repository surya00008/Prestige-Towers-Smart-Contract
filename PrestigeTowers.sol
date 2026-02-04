// SPDX-License-Identifier: GPL-3.0
// 10000000000000000000 wei = 10 eth

pragma solidity ^0.8.0;

contract PrestigeTowers{

    address payable public owner;
    uint public totalFlats;
    uint public flatPrice;
    string public projectName;
    uint public endTime;
    uint public totalBuyers;
    uint public soldFlats;
    uint public totalVote;
    uint public votingStartTime;
    uint public constant VOTING_DURATION = 300; // 5 minutes
    bool contractFundClaimed;

    enum ProjectState {             // explicit project state
        Booking,  // booking + deposits
        Voting,  // project ended, voting ongoing
        Settled  // funds settled
    }

    ProjectState public state;

    struct BuyerDetails {
        address payable buyerAddress;
        uint totalAmountPaid;
        uint amountRemaining;
        bool fundClaimed;
    }

    BuyerDetails[] public buyerDetails;        //Array to store buyer details
    mapping(address=>uint) public buyerMap;
    mapping(address=>bool) public voted;
    mapping(address => bool) public buyerExists;   // buyer existence to be explicit, design principle: Never infer existence from array indices. Track it explicitly. Now contract answers with “Is this address a buyer?”
                                                            
    event Message(string msg);
    event StateChanged(ProjectState from, ProjectState to);


    constructor(uint _totalFlats, uint _flatPrice, string memory _projectName, uint _endTime){
        owner = payable(msg.sender);
        endTime = block.timestamp + _endTime;
        totalFlats = _totalFlats;
        flatPrice = _flatPrice;
        projectName = _projectName;
        state = ProjectState.Booking;
        buyerDetails.push();         // dummy index 0
    }

     modifier onlyOwner() {
    require(msg.sender == owner, "Only owner allowed");
    _;
    }

    function moveToVoting() external onlyOwner {
    require(state == ProjectState.Booking, "Invalid state transition");
    require(block.timestamp >= endTime, "Booking period not ended");

    ProjectState previous = state;
    state = ProjectState.Voting;
    votingStartTime = block.timestamp;

    emit StateChanged(previous, state);
    }

    function buyFlat() external payable {
        require(state == ProjectState.Booking, "Booking phase ended");
        require(msg.sender != owner, "Onwer cannot buy flat !!");
        require(!buyerExists[msg.sender], "Buyer already exists");
        require(msg.value < flatPrice, "Please check the flat price !!");
        require(msg.value > 0, "Minimum price to book is 1eth !!");
        require(soldFlats<totalFlats, "All flats are sold !!");

        BuyerDetails memory buyer = BuyerDetails({
            buyerAddress: payable(msg.sender),
            totalAmountPaid: msg.value,
            amountRemaining: flatPrice - msg.value,
            fundClaimed: false
        });

        soldFlats++;
        totalBuyers++;
        buyerDetails.push(buyer);
        buyerMap[msg.sender] = buyerDetails.length-1;
        buyerExists[msg.sender] = true;
        emit Message("Flat bought !!");
        }

    function getBuyerDetails() external view returns (BuyerDetails memory) {
    require(buyerExists[msg.sender], "Buyer does not exist");

    uint location = buyerMap[msg.sender];
    BuyerDetails memory buyer = buyerDetails[location];

    require(buyer.buyerAddress == msg.sender, "Invalid buyer record");
    return buyer;
    }


    function depositFund() external payable {
    require(state == ProjectState.Booking, "Booking phase ended");
    require(msg.sender != owner, "Owner cannot deposit");
    require(buyerExists[msg.sender], "Buyer does not exist");

    uint location = buyerMap[msg.sender];
    BuyerDetails storage buyer = buyerDetails[location];

    require(buyer.buyerAddress == msg.sender, "Invalid buyer record");
    require(buyer.amountRemaining > 0, "Flat already fully paid");
    require(msg.value > 0, "Deposit amount must be greater than zero");
    require(msg.value <= buyer.amountRemaining, "Exceeds remaining amount");

    buyer.totalAmountPaid += msg.value;
    buyer.amountRemaining -= msg.value;

    emit Message("Money deposited");
    }


    function getContractBalance() external view returns(uint) {
        return address(this).balance;
    }

    function putVote() external {
    require(state == ProjectState.Voting, "Voting phase not active");
    require(block.timestamp <= votingStartTime + VOTING_DURATION,"Voting period ended");
    require(msg.sender != owner, "Owner cannot vote");
    require(buyerExists[msg.sender], "Buyer does not exist");

    uint location = buyerMap[msg.sender];
    require(buyerDetails[location].buyerAddress == msg.sender, "Invalid buyer");
    require(!voted[msg.sender], "Already voted");

    voted[msg.sender] = true;
    totalVote++;
    }

    function _autoSettleIfNeeded() internal {
    if (
        state == ProjectState.Voting &&
        block.timestamp > votingStartTime + VOTING_DURATION) {
        ProjectState previous = state;
        state = ProjectState.Settled;
        emit StateChanged(previous, state);
        }
    }

    function claimFundContractor() public {
    // Voting must be over — no early settlement
    require(block.timestamp > votingStartTime + VOTING_DURATION,"Voting period not ended");
    _autoSettleIfNeeded(); // will move state to Settled if needed
    require(state == ProjectState.Settled, "Project not settled");
    require(msg.sender == owner, "Only contractor");
    require(totalVote > totalBuyers / 2, "Majority does not support");
    require(!contractFundClaimed, "Funds already claimed");

    contractFundClaimed = true;

    uint amount = address(this).balance;
    (bool success, ) = owner.call{value: amount}("");
    require(success, "Contractor ETH transfer failed");
    }

    function claimFundUser() public {
        require(
    block.timestamp > votingStartTime + VOTING_DURATION,"Voting period not ended");

    require(state == ProjectState.Settled, "Project not settled");
    require(buyerExists[msg.sender], "Buyer does not exist");
    require(msg.sender != owner, "Owner cannot claim refund");
    require(totalVote < totalBuyers / 2, "Majority supports contractor");

    uint location = buyerMap[msg.sender];
    BuyerDetails storage buyer = buyerDetails[location];

    require(buyer.buyerAddress == msg.sender, "Invalid buyer");
    require(!buyer.fundClaimed, "Funds already claimed");

    uint amount = buyer.totalAmountPaid;
    buyer.totalAmountPaid = 0;
    buyer.fundClaimed = true;

    (bool success, ) = buyer.buyerAddress.call{value: amount}("");
    require(success, "Refund failed");
    }
}
