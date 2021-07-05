//SPDX-License-Identifier: AGPL-3.0-or-later

//Waffle v1.2

pragma solidity ^0.8.0;

// ============ Imports ============

import "./Openzeppelin-Interfaces/IERC721.sol";
import "./Openzeppelin-Interfaces/IERC721Receiver.sol";
import "./chainlink/VRFConsumerBase.sol";

contract Waffle is VRFConsumerBase, IERC721Receiver {
  // ============ Immutable storage ============

  // Chainlink keyHash
  bytes32 internal immutable keyHash;
  // Chainlink fee
  uint256 internal immutable fee; 
  // NFT owner
  address public immutable owner;
  // Price (in Ether) per raffle slot
  uint256 public immutable slotPrice;
  // Number of total available raffle slots
  uint256 public immutable numSlotsAvailable;

  // ============ Mutable storage ============

  //No of NFTs
  uint256 public nftCount;
  // Addresses of NFT contracts
  address[] public nftContract;
  // NFT ID's
  uint256[] public nftID;
  // Results from Chainlink VRF
  uint256[] public randomResult;
  // Increment when contract requests result from Chainlink VRF
  uint256 public randomResultRequested = 0;
  // Number of filled raffle slots
  uint256 public numSlotsFilled = 0;
  // Array of slot owners
  address[] public slotOwners;
  // Mapping of slot owners to number of slots owned
  mapping(address => uint256) public addressToSlotsOwned;
  // No of NFT's available in the contract to raffle
  uint256 public nftOwned = 0;

  // ============ Events ============

  // Address of slot claimee and number of slots claimed
  event SlotsClaimed(address indexed claimee, uint256 numClaimed);
  // Address of slot refunder and number of slots refunded
  event SlotsRefunded(address indexed refunder, uint256 numRefunded);
  // Address of raffle winner
  event RaffleWon(address indexed winner);

  // ============ Constructor ============

  constructor(
    address _owner,
    address _ChainlinkVRFCoordinator,
    address _ChainlinkLINKToken,
    bytes32 _ChainlinkKeyHash,
    uint256 _ChainlinkFee,
    uint256 _nftCount,
    uint256 _slotPrice, 
    uint256 _numSlotsAvailable
  ) VRFConsumerBase(
    _ChainlinkVRFCoordinator,
    _ChainlinkLINKToken
  ) {
    owner = _owner;
    keyHash = _ChainlinkKeyHash;
    fee = _ChainlinkFee;
    nftCount = _nftCount;
    slotPrice = _slotPrice;
    numSlotsAvailable = _numSlotsAvailable;
  }

  // ============ Functions ============

  /**
   * Enables purchasing _numSlots slots in the raffle
   */
  function purchaseSlot(uint256 _numSlots) payable external {
    // Require purchasing at least 1 slot
    require(_numSlots > 0, "Waffle: Cannot purchase 0 slots.");
    // Require the raffle contract to own the NFT to raffle
    require(nftOwned == nftCount, "Waffle: Contract does not own raffleable NFT/NFTs.");
    // Require there to be available raffle slots
    require(numSlotsFilled < numSlotsAvailable, "Waffle: All raffle slots are filled.");
    // Prevent claiming after winner selection
    require(randomResultRequested == 0, "Waffle: Cannot purchase slot after winner has been chosen.");
    // Require appropriate payment for number of slots to purchase
    require(msg.value == _numSlots * slotPrice, "Waffle: Insufficient ETH provided to purchase slots.");
    // Require number of slots to purchase to be <= number of available slots
    require(_numSlots <= numSlotsAvailable - numSlotsFilled, "Waffle: Requesting to purchase too many slots.");


    // For each _numSlots
    for (uint256 i = 0; i < _numSlots; i++) {
      // Add address to slot owners array
      slotOwners.push(msg.sender);
    }

    // Increment filled slots
    numSlotsFilled = numSlotsFilled + _numSlots;
    // Increment slots owned by address
    addressToSlotsOwned[msg.sender] = addressToSlotsOwned[msg.sender] + _numSlots;

    // Emit claim event
    emit SlotsClaimed(msg.sender, _numSlots);
  }

  /**
   * Deletes raffle slots and decrements filled slots
   * @dev gas optimization: could force one-tx-per-slot-deletion to prevent iteration
   */
  function refundSlot(uint256 _numSlots) external {
    // Require the raffle contract to own the NFT to raffle
    require(nftOwned == nftCount, "Waffle: Contract does not own raffleable NFT/NFTs.");
    // Prevent refunding after winner selection
    require(randomResultRequested == 0, "Waffle: Cannot refund slot after winner has been chosen.");
    // Require number of slots owned by address to be >= _numSlots requested for refund
    require(addressToSlotsOwned[msg.sender] >= _numSlots, "Waffle: Address does not own number of requested slots.");

    // Delete slots
    uint256 idx = 0;
    uint256 numToDelete = _numSlots;
    // Loop through all entries while numToDelete still exist
    while (idx < slotOwners.length && numToDelete > 0) {
      // If address is not a match
      if (slotOwners[idx] != msg.sender) {
        // Only increment for non-matches. In case of match keep same to check against last idx item
        idx++;
      } else {
        // Swap and pop
        slotOwners[idx] = slotOwners[slotOwners.length - 1];
        slotOwners.pop();
        // Decrement num to delete
        numToDelete--;
      }
    }

    // Repay raffle participant
    payable(msg.sender).transfer(_numSlots * slotPrice);
    // Decrement filled slots
    numSlotsFilled = numSlotsFilled - _numSlots;
    // Decrement slots owned by address
    addressToSlotsOwned[msg.sender] = addressToSlotsOwned[msg.sender] - _numSlots;

    // Emit refund event
    emit SlotsRefunded(msg.sender, _numSlots);
  }

  /**
   * Collects randomness from Chainlink VRF to propose a winner.
   */
  function collectRandomWinner() external returns (bytes32 requestId) {
    // Require at least 1 raffle slot to be filled
    require(numSlotsFilled > 0, "Waffle: No slots are filled");
    // Require NFTs to be owned by raffle contract
    require(nftOwned == nftCount, "Waffle: Contract does not own raffleable NFT/NFTs.");
    // Require caller to be raffle deployer
    require(msg.sender == owner, "Waffle: Only owner can call winner collection.");
    // Require randomness is requested only as many times as nfts owned
    require(randomResultRequested < nftOwned, "Waffle: Cannot collect more winners.");

    // Call for random number
    return requestRandomness(keyHash, fee);
  }

  /**
   * Collects random number from Chainlink VRF
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    // Store random number as randomResult
    randomResult[randomResultRequested] = randomness;

    // Increment randomness requested
    randomResultRequested++;
  }

  /**
   * Disburses NFT to winner and raised raffle pool to owner
   */
  function disburseWinner() external {
    // Require that the contract holds the NFTs
    require(nftOwned == nftCount, "Waffle: Cannot disurbse NFT to winner without holding NFT/NFTs.");
    // Require that a winner has been collected already
    require(randomResultRequested == nftOwned, "Waffle: Cannot disburse to winners without having collected all of them.");
    // Require that the random result is not 0
    require(randomResult[randomResultRequested] > 0, "Waffle: Please wait for Chainlink VRF to update the winner first.");
    
    while (nftOwned > 0) {
      // Find winner of NFT
      address winner = slotOwners[randomResult[randomResultRequested-1] % numSlotsFilled];

      // Transfer NFT to winner
      IERC721(nftContract[nftOwned-1]).safeTransferFrom(address(this), winner, nftID[nftOwned-1]);

      // Decrement nftOwned
      nftOwned--;

      // Decrement randomResultRequested
      randomResultRequested--;

      // Emit raffle winner
      emit RaffleWon(winner);

    }
    
    // Transfer raised raffle pool to owner
    payable(owner).transfer(address(this).balance);

  }

  /**
   * Deletes raffle, assuming that contract owns NFT and a winner has not been selected
   */
  function deleteRaffle() external {
    // Require being owner to delete raffle
    require(msg.sender == owner, "Waffle: Only owner can delete raffle.");
    // Require that the contract holds the NFT
    require(nftOwned == nftCount, "Waffle: Cannot cancel raffle without raffleable NFT/NFTs.");
    // Require that a winner has not been collected already
    require(randomResultRequested == 0, "Waffle: Cannot delete raffle after collecting winner.");


    while (nftOwned > 0) {
      // Transfer NFT to original owner
      IERC721(nftContract[nftOwned-1]).safeTransferFrom(address(this), msg.sender, nftID[nftOwned-1]);

      // Decrement nftOwned
      nftOwned--;

    }


    // For each slot owner
    for (uint256 i = numSlotsFilled - 1; i >= 0; i--) {
      // Refund slot owner
      payable(slotOwners[i]).transfer(slotPrice);
      // Pop address from slot owners array
      slotOwners.pop();
    }
  }

  /**
   * Receive NFT's to raffle
   */
  function onERC721Received(
    address operator,
    address from, 
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {

    //NFT Contract added to the list
    nftContract[nftOwned] = from;

    //NFT ID added to the list
    nftID[nftOwned] = tokenId;

    // Increment no of NFT's available in the contract to raffle
    nftOwned++;

    // Return required successful interface bytes
    return 0x150b7a02;
  }


