const puppeteer = require('puppeteer');

(async () => {
  const browserURL = 'http://localhost:9224';
  const browser = await puppeteer.connect({browserURL});  
  const page = await browser.newPage();
  page.goto('http://192.168.47.88:9876');
})();
