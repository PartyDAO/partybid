const MARKET_NAMES = {
  ZORA: 'ZORA',
  FOUNDATION: 'FOUNDATION',
  NOUNS: 'NOUNS',
};

// MARKETS is an array of all values in MARKET_NAMES
const MARKETS = Object.keys(MARKET_NAMES).map(key => MARKET_NAMES[key]);

const NFT_TYPE_ENUM = {
  ZORA: 0,
  FOUNDATION: 1,
  NOUNS: 2,
};

module.exports = {
  MARKETS,
  MARKET_NAMES,
  NFT_TYPE_ENUM,
};
