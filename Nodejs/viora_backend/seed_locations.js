require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

const Continent = require('./src/models/continent.model');
const Nation = require('./src/models/nation.model');
const City = require('./src/models/city.model');
const Ward = require('./src/models/ward.model');

async function runSeed() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error('❌ MONGODB_URI is not set in .env');
    process.exit(1);
  }

  console.log('🔄 Connecting to MongoDB Atlas...');
  await mongoose.connect(uri);
  console.log('✅ Connected to MongoDB Atlas successfully!');

  const filePath = path.join(__dirname, 'location.json');
  if (!fs.existsSync(filePath)) {
    console.error('❌ File location.json not found at:', filePath);
    process.exit(1);
  }

  const rawData = fs.readFileSync(filePath, 'utf-8');
  let data;
  try {
    data = JSON.parse(rawData);
  } catch (err) {
    console.error('❌ Failed to parse JSON from location.json:', err.message);
    process.exit(1);
  }

  console.log(`📦 Loaded location.json containing ${data.length} continent entries.`);

  let continentCount = 0;
  let nationCount = 0;
  let cityCount = 0;
  let wardCount = 0;

  for (const item of data) {
    const contName = (item.nameContinent || '').trim();
    if (!contName) continue;

    let continentDoc = await Continent.findOne({ nameContinent: contName });
    if (!continentDoc) {
      continentDoc = await Continent.create({ nameContinent: contName });
      console.log(`  ➕ Created Continent: ${contName}`);
    } else {
      console.log(`  ✓ Existing Continent: ${contName}`);
    }
    continentCount++;

    const nations = Array.isArray(item.nations) ? item.nations : [];
    for (const n of nations) {
      const natName = (n.nameNation || '').trim();
      if (!natName) continue;

      const numNation = (n.numberNation || '').trim();
      const code = (n.code || '').trim();

      let nationDoc = await Nation.findOne({ nameNation: natName });
      if (!nationDoc) {
        nationDoc = await Nation.create({
          nameNation: natName,
          numberNation: numNation,
          code: code,
          continentId: continentDoc._id,
        });
        console.log(`    ➕ Created Nation: ${natName}`);
      } else {
        nationDoc.continentId = continentDoc._id;
        if (numNation) nationDoc.numberNation = numNation;
        if (code) nationDoc.code = code;
        await nationDoc.save();
        console.log(`    ✓ Updated Nation: ${natName}`);
      }
      nationCount++;

      const cities = Array.isArray(n.cities) ? n.cities : [];
      for (const c of cities) {
        const cityName = (c.nameCity || '').trim();
        if (!cityName) continue;

        let cityDoc = await City.findOne({
          nameCity: cityName,
          nationId: nationDoc._id,
        });
        if (!cityDoc) {
          cityDoc = await City.create({
            nameCity: cityName,
            nationId: nationDoc._id,
          });
        }
        cityCount++;

        const existingWards = new Set(
          (await Ward.find({ cityId: cityDoc._id }).select('nameWard').lean()).map(
            (w) => w.nameWard
          )
        );

        const rawWards = Array.isArray(c.wards) ? c.wards : [];
        const seenInBatch = new Set();
        const wardDocsToInsert = [];

        for (const w of rawWards) {
          if (!w || typeof w !== 'string') continue;
          const wardName = w.trim();
          if (!wardName) continue;

          if (!existingWards.has(wardName) && !seenInBatch.has(wardName)) {
            seenInBatch.add(wardName);
            wardDocsToInsert.push({
              nameWard: wardName,
              cityId: cityDoc._id,
            });
          }
        }

        if (wardDocsToInsert.length > 0) {
          await Ward.insertMany(wardDocsToInsert, { ordered: false });
          wardCount += wardDocsToInsert.length;
        }
      }
    }
  }

  // Count totals currently in database for verification
  const totalContinents = await Continent.countDocuments();
  const totalNations = await Nation.countDocuments();
  const totalCities = await City.countDocuments();
  const totalWards = await Ward.countDocuments();

  console.log('\n🎉 =====================================');
  console.log('🎉 SEED COMPLETED TO MONGODB ATLAS!');
  console.log(`   - Newly inserted wards : ${wardCount}`);
  console.log('   ---------------------------------');
  console.log('📊 TOTAL IN MONGODB ATLAS RIGHT NOW:');
  console.log(`   - Continents : ${totalContinents}`);
  console.log(`   - Nations    : ${totalNations}`);
  console.log(`   - Cities     : ${totalCities}`);
  console.log(`   - Wards      : ${totalWards}`);
  console.log('===================================== 🎉\n');

  await mongoose.disconnect();
  console.log('👋 Disconnected from MongoDB.');
}

runSeed().catch((err) => {
  console.error('❌ Error seeding locations to MongoDB Atlas:', err);
  process.exit(1);
});
