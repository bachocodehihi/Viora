const vi = require('./vi');
const en = require('./en');

const locales = {
  vi,
  en,
};

const getLocale = (language = 'en') => {
  return locales[language] || locales.en;
};

const t = (language, path, params = {}) => {
  const locale = getLocale(language);
  const keys = path.split('.');
  let result = locale;

  for (const key of keys) {
    if (result && result[key] !== undefined) {
      result = result[key];
    } else {
      return path;
    }
  }

  if (typeof result === 'string' && Object.keys(params).length > 0) {
    return result.replace(/\{(\w+)\}/g, (match, key) => {
      return params[key] !== undefined ? params[key] : match;
    });
  }

  return result;
};

const supportedLanguages = Object.keys(locales);

module.exports = {
  locales,
  getLocale,
  t,
  supportedLanguages,
};
