pragma solidity ^0.8.6;

interface IOffer {

    struct Offer {
        // IPFS path for the propsoed image/metadata.
        string uriPath;
        // The address to pay proceeds if this offer wins an auction.
        address payoutAddress;
        // Count of the total votes in favor of this
        // offer.
        uint voteCount;
    }

    struct OfferPeriod {
        // ID for the Offer period
        uint256 id;
        // The block where the offer submission period is scheduled to begin.
        uint256 offerStartBlock;
        // The block where the offer submission period is scheduled to end and
        // voting should begin.
        uint256 offerEndBlock;
        // The block where voting is scheduled to end
        uint256 votingEndBlocks;
        // If this offer period has already been settled.
        bool settled;
    }

    event KoanVoted(uint256 indexed koanId, uint256 offerPeriodId, uint256 offerId);

    event SashoVoted(address indexed sashoAddress, uint256 offerPeriodId, uint256 offerId, uint256 sashoVotes);

    event OfferPeriodSettled(uint256 offerPeriodId, string uriPath, address artist);

    event OfferPeriodCreated(uint256 offerPeriodId);

    event OfferPeriodEndedWithoutProposal(uint256 offerPeriodId);

    event OfferPeriodEndedWithoutVotes(uint256 offerPeriodId);

    event ArtOffered(uint256 indexed offerPeriodId, address indexed submitter, uint256 offerIndex, string uriPath, address payoutAddress);

    event KoanVotingWeightUpdated(uint256 koanVotingWeight);

    event MinCollateralUpdated(uint256 minCollateral);

    event OfferFeeUpdated(uint256 offerFee);

    event OfferDurationBlocksUpdated(uint256 offerDurationBlocks);

    event VotingPeriodDurationBlocksUpdated(uint256 votingPeriodDurationBlocks);

    function pause() external;

    function unpause() external;

    function settleOfferPeriod() external;

    function settleCurrentAndCreateNewOfferPeriod() external;

    function setKoanVotingWeight(uint koanVotingWeight_) external;

    function setMinCollateral(uint minCollateral_) external;

    function setOfferFee(uint offerFee_) external;

    function setOfferDurationBlocks(uint offerDurationBlocks_) external;

    function setVotingPeriodDurationBlocks(uint votingPeriodDurationBlocks_) external;

}