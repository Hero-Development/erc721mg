
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

struct StakeSummary{
  uint32 started; //32
  uint32 total;   //64
  uint16 tokenId; //80
}

interface IGakkoRewards{
  function handleRewards( address to, StakeSummary[] calldata claims ) external;
  function handleStakes( uint16[] calldata tokenIds ) external;
}
