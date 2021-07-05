# Waffle v1.2

Waffle v1.2 is a multi NFT raffles inspired by [Jon Itzler](https://twitter.com/jonitzler/status/1408472539182120967) & Anish's Waffle

In v1.2 multiple NFTs can be raffled together in a single raffle.

1. NFT Owners can specify the number of NFTs, number of available raffle slots, and price per slot.
2. Entrants can deposit and withdraw until all slots are filled.
3. Owners can raffle the NFTs and select winners at any point (slots filled or not).

Additionally:

1. Owners can delete a raffle so long as a winners haven't been selected.


## Architecture

`Waffle.sol` is a full-fledged raffle system that enables the deposit, withdrawal, and post-raffle disbursement of an `ERC721` NFTs. Randomness during winner selection is guaranteed through the use of a [Chainlink VRF oracle](https://docs.chain.link/docs/chainlink-vrf/).

`WaffleFactory.sol` is the factory deployed for child `Waffle.sol` instances. It simplifies the deployment of a raffle and ensures that deployers pre-fund `Waffle.sol` instances with the `LINK` necessary to retrieve random results from the Chainlink oracle.

## Credits

[Freepik](https://www.flaticon.com/free-icon/stroopwafel_3531066?term=waffle&page=1&position=3&page=1&position=3&related_id=3531066&origin=search#) for the icon.
