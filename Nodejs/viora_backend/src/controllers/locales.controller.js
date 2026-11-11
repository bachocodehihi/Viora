const { supportedLanguages } = require('../locales');

const getSupportedLanguages = async (req, res) => {
  try {
    return res.status(200).json({
      languages: supportedLanguages,
      default: 'en',
    });
  } catch (error) {
    return res.status(500).json({ 
      code: 'GET_LANGUAGES_FAILED',
      message: 'Failed to get supported languages' 
    });
  }
};

module.exports = {
  getSupportedLanguages,
};
