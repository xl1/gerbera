var Gerbera = require('./src/Gerbera');
if('self' in global){
  global.Gerbera = Gerbera;
} else {
  module.exports = Gerbera;
}
