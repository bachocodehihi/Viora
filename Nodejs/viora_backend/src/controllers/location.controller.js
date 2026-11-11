const Nation = require('../models/nation.model');
const City = require('../models/city.model');
const Ward = require('../models/ward.model');
const Continent = require('../models/continent.model');

const getNations = async (req, res) => {
  try {
    const [continents, nations] = await Promise.all([
      Continent.find({}).sort({ nameContinent: 1 }).select('nameContinent').lean(),
      Nation.find({})
        .sort({ nameNation: 1 })
        .select('nameNation numberNation code continentId')
        .populate('continentId', 'nameContinent')
        .lean()
    ]);

    const formattedNations = nations.map(item => ({
      _id: item._id,
      nameNation: item.nameNation,
      code: item.code,
      numberNation: item.numberNation,
      continent: item.continentId ? item.continentId.nameContinent : '',
    }));

    return res.status(200).json({
      success: true,
      continents: continents.map(c => c.nameContinent),
      data: formattedNations,
    });
  } catch (error) {
    console.error('Error fetching nations:', error);
    return res.status(500).json({
      success: false,
      code: 'FETCH_NATIONS_FAILED',
      message: 'Failed to fetch nations',
    });
  }
};

const getCities = async (req, res) => {
  try {
    const { nationId, nationName } = req.query;
    let targetNationId = nationId;

    if (!targetNationId && nationName) {
      const nation = await Nation.findOne({
        nameNation: new RegExp(`^${String(nationName).trim()}$`, 'i'),
      }).select('_id').lean();
      if (nation) targetNationId = nation._id;
    }

    if (!targetNationId) {
      return res.status(200).json({ success: true, data: [] });
    }

    const cities = await City.find({ nationId: targetNationId })
      .sort({ nameCity: 1 })
      .select('nameCity nationId')
      .lean();

    return res.status(200).json({
      success: true,
      data: cities,
    });
  } catch (error) {
    console.error('Error fetching cities:', error);
    return res.status(500).json({
      success: false,
      code: 'FETCH_CITIES_FAILED',
      message: 'Failed to fetch cities',
    });
  }
};

const getWards = async (req, res) => {
  try {
    const { cityId, cityName } = req.query;
    let targetCityId = cityId;

    if (!targetCityId && cityName) {
      const city = await City.findOne({
        nameCity: new RegExp(`^${String(cityName).trim()}$`, 'i'),
      }).select('_id').lean();
      if (city) targetCityId = city._id;
    }

    if (!targetCityId) {
      return res.status(200).json({ success: true, data: [] });
    }

    const wards = await Ward.find({ cityId: targetCityId })
      .sort({ nameWard: 1 })
      .select('nameWard cityId')
      .lean();

    return res.status(200).json({
      success: true,
      data: wards,
    });
  } catch (error) {
    console.error('Error fetching wards:', error);
    return res.status(500).json({
      success: false,
      code: 'FETCH_WARDS_FAILED',
      message: 'Failed to fetch wards',
    });
  }
};

module.exports = {
  getNations,
  getCities,
  getWards,
};
