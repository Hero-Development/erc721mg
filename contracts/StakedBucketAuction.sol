
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BucketAuction.sol";
import "./Shared/IGakkoLoot.sol";
import "./Shared/IGakkoRewards.sol";

contract StakedBucketAuction is BucketAuction{
  error IncorrectOwner();
  error InvalidStake();
  error NoTokensSpecified();
  error StakingInactive();
  error TransferWhileStaked();

  struct StakeData{
    uint32 started; // 32
    uint32 total;   // 64
  }

  struct StakeInfo{
    uint16 tokenId;
    uint32 accrued;
    uint32 pending;
    bool isStaked;
  }

  uint32 public baseAward;
  bool public isStakeable;
  IGakkoLoot public lootHandler;
  IGakkoRewards public rewardHandler;
  mapping(uint256 => StakeData) public stakes;

  constructor(
    string memory collectionName,
    string memory collectionSymbol,
    string memory tokenURISuffix,
    uint256 maxMintableSupply,
    uint256 globalWalletLimit,
    address cosigner,
    uint256 minimumContributionInWei,
    uint64 startTimeUnixSeconds,
    uint64 endTimeUnixSeconds
  )
    BucketAuction(
      collectionName,
      collectionSymbol,
      tokenURISuffix,
      maxMintableSupply,
      globalWalletLimit,
      cosigner,
      minimumContributionInWei,
      startTimeUnixSeconds,
      endTimeUnixSeconds
    )
  {
    baseAward = 0;
  }


  //nonpayable - public
  function claimTokens( uint16[] calldata tokenIds, bool restake ) external {
    if( tokenIds.length == 0 ) revert NoTokensSpecified();

    uint256 length = tokenIds.length;
    uint32 time = uint32(block.timestamp);
    StakeSummary[] memory claims = new StakeSummary[](tokenIds.length);
    for(uint256 i = 0; i < length; ++i ){
      //checks
      uint16 tokenId = tokenIds[i];
      if( ERC721A.ownerOf( tokenId ) != msg.sender ) revert IncorrectOwner();

      StakeData memory stake = stakes[ tokenId ];
      if( stake.started < 2 ){
        claims[ i ] = StakeSummary(
          stake.total,
          stake.total,
          tokenId
        );
      }
      else{
        
        uint32 accrued = ( time - stake.started );
        if( stake.total == 0 )
          accrued += baseAward;


        claims[ i ] = StakeSummary(
          stake.total,
          stake.total + accrued,
          tokenId
        );


        //effects
        stakes[ tokenId ] = StakeData(
          restake ? time : 1,
          stake.total + accrued
        );
      }
    }

    //interactions
    if( address(rewardHandler) != address(0) ){
      rewardHandler.handleRewards( msg.sender, claims );
    }
  }

  function stakeTokens( uint16[] calldata tokenIds ) external {
    if( tokenIds.length == 0 ) revert NoTokensSpecified();
    if( !isStakeable ) revert StakingInactive();

    uint32 time = uint32(block.timestamp);
    for(uint256 i; i < tokenIds.length; ++i ){
      //checks
      uint16 tokenId = tokenIds[i];
      if( ERC721A.ownerOf(tokenId) != msg.sender ) revert IncorrectOwner();

      StakeData storage stake = stakes[ tokenId ];
      if( stake.started > 1 ) continue;

      //effects
      stake.started = time;
    }

    //interactions
    if( address(rewardHandler) != address(0) ){
      rewardHandler.handleStakes( tokenIds );
    }
  }


  //payable - public - override
  function transferFrom(address from, address to, uint256 tokenId)
    public
    payable
    override( ERC721A, IERC721A ) {
    if( _isStaked(tokenId) ) revert TransferWhileStaked();

    super.transferFrom( from, to, tokenId );

    //if transfer succeeded, pull is valid
    if( address(lootHandler) != address(0) ){
      lootHandler.handlePull( from, to, uint16(tokenId) );
    }
  }


  //nonpayable - admin
  function setBaseAward( uint32 award ) external onlyOwner{
    baseAward = award;
  }

  function setHandlers( IGakkoRewards reward, IGakkoLoot loot ) external onlyOwner{
    rewardHandler = reward;
    lootHandler = loot;
  }

  function setStakeable( bool stakeable ) external onlyOwner{
    isStakeable = stakeable;
  }


  //view - public
  function getStakeInfo( uint16[] calldata tokenIds ) external view returns (StakeInfo[] memory infos) {
    uint32 time = uint32(block.timestamp);

    infos = new StakeInfo[]( tokenIds.length );
    for(uint256 i; i < tokenIds.length; ++i ){
      StakeData memory stake = stakes[ tokenIds[i] ];
      if( stake.started > 1 ){
        uint32 pending = time - stake.started;
        if( stake.total == 0 )
          pending += baseAward;

        infos[i] = StakeInfo(
          tokenIds[i],
          stake.total,
          pending,
          true
        );
      }
      else{
        infos[i] = StakeInfo(
          tokenIds[i],
          stake.total,
          0,
          false
        );
      }
    }
  }


  //view - override
  function ownerOf( uint256 tokenId )
    public
    view
    override( ERC721A, IERC721A )
    returns( address currentOwner ){
    if (tokenId > type(uint16).max || !_exists(tokenId))
      revert URIQueryForNonexistentToken();

    if( stakes[ uint16(tokenId) ].started > 1 )
      currentOwner = address(this);
    else
      currentOwner = super.ownerOf( tokenId );
  }


  //view - internal
  function _isStaked( uint256 tokenId ) internal view returns( bool ){
    return stakes[ tokenId ].started > 1;
  }
}
