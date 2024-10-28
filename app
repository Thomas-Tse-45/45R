const axios = require('axios');
const express = require('express');
const puppeteer = require('puppeteer');

const app = express();
const port = 3000;

const BASE_URL = 'https://shop.45r.jp/shop/g/g';
const getProductUrl = (productId) => `${BASE_URL}${productId}/`;

async function scrapeProductInfo(productId) {
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();

    // Set a custom User-Agent in Puppeteer
    await page.setUserAgent('MyApp/0.0.1');
    
    const url = getProductUrl(productId);

    // Fetch the HTML content with Axios
    const response = await axios.get(url, {
        headers: {
            'ngrok-skip-browser-warning': '1',
            'User-Agent': 'MyApp/0.0.1'
        }
    }).catch(err => {
        console.error("Axios error:", err);
    });
    console.log("Axios response:", response.data);


    await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 }); // 60 seconds


    // Scrape the data
    let data = await page.evaluate((productId) => {
        // Product description
        let descriptionElement = document.querySelector('.item_description_ .text_ p');
        let description = descriptionElement ? descriptionElement.innerHTML : 'N/A';

        // Remove unwanted warranty text
        const removeUnwantedText = (html) => {
          const unwantedTexts = [
              '<br><br>こちらは4.5年保証の対象製品です。<br>4.5年保証については<a href="https://45ronlinestore.jp/shop/pages/repairservice.aspx#aiindigo_care_"><font color="blue">こちら</font></a>',
              '藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</a></font>'
          ];

          unwantedTexts.forEach(unwantedText => {
              html = html.replace(new RegExp(unwantedText, 'g'), '').trim();
          });

         return html;
        };

        // Clean and reorder description HTML
        const cleanAndReorderDescriptionHTML = (html) => {
          html = removeUnwantedText(html);

          // Split the description into parts by <br><br>
          let parts = html.split('<br><br>').filter(part => part.trim() !== '');

          // Remove any part that contains the unwanted text or <a href= ...> tag
          parts = parts.filter(part => !part.includes('4.5年保証') && !part.includes('<a href='));

          // Reorder the parts if more than one
          if (parts.length > 1) {
              const lastPart = parts.pop();
              html = lastPart + '<br><br>' + parts.join('<br><br>');
          } else {
              html = parts.join('<br><br>');
          }

          // Ensure each paragraph break is followed by <br><br>
          html = html.replace(/<br>\s*(?!<br>)/g, '<br><br>');

          return html;
        };

        // Apply cleaning and reordering to the description
        description = cleanAndReorderDescriptionHTML(description);

        // Remove \n after <br> tags and any other \n characters in description
        description = description.replace(/<br>\n/g, ' ').replace(/\n\s*/g, ' ').replace(/\s\s+/g, ' ')
            .replace(/<br><br><br>/g, '<<br>>').replace(/<br><br>/g, '').replace(/<<br>>/g, '<br><br>').replace(/<br><br><br>/g, '<br><br>').trim();

        // Size chart
        let sizeChartElement = document.querySelector('.size_table_ table');
        let sizeChartHtml = sizeChartElement ? sizeChartElement.innerHTML : 'N/A';

        // Translate and format the size chart
        const sizeChartTranslations = {
            'サイズ': 'SIZE',
            'バスト': 'CHEST',
            '着丈': 'LENGTH',
            'スカート丈': 'LENGTH',
            '肩幅': 'SHOULDER<br>WIDTH',
            '袖丈': 'SLEEVE<br>LENGTH',
            '裄丈': 'SLEEVE<br>LENGTH',
            '幅': 'WIDTH',
            'モチーフタテ' : 'MOTIF<br>HEIGHT',
            'モチーフヨコ' : 'MOTIF<br>WIDTH',
            '高さ': 'HEIGHT',
            'マチ': 'GUSSET',
            'ショルダー': 'SHOULDER<br>STRAP',
            '持ち手': 'HANDLE',
            'ウエスト': 'WAIST',
            'ヒップ': 'HIPS',
            '股上': 'FRONT<br>RISE',
            '股下': 'INSEAM',
            'ワタリ': 'THIGH<br>WIDTH',
            '裾幅': 'HEM<br>WIDTH',
            '全長': 'OVERALL<br>LENGTH',
            'タテ': 'HEIGHT',
            'ヨコ': 'WIDTH',
            '頭周': 'HEAD<br>CIRCUMFERENCE',
            '深さ': 'DEPTH',
            'ツバ': 'BRIM',
            '全長': 'FULL<br>LENGTH',
            'モチーフ': 'WIDTH',
            '身幅': 'CHEST',
            '剣先幅': 'TIP<br>WIDTH',
            '対応サイズ': 'COMPATIBLE<br>SIZES',
            'フリー': 'One Size',
            '頭囲': 'HEAD CIRCUMFERENCE',
            'モチーフ高さ': 'MOTIF<br>HEIGHT',
            'モチーフ直径': 'MOTIF<br>DIAMETER',
            'マフラー幅':'MOTIF<br>WIDTH'
        };

        const translateAndFormatSizeChart = (html, sizeMap) => {
            Object.keys(sizeChartTranslations).forEach(key => {
                html = html.replace(new RegExp(`>${key}<`, 'g'), `>${sizeChartTranslations[key]}<`);
                html = html.replace(new RegExp(`>${key}`, 'g'), `>${sizeChartTranslations[key]}`);
            });

            // Translate "インチ" to "Inch" within the cell value
            html = html.replace(/(\d+\.?\d*)インチ/g, '$1Inch');

            // Convert to inches and create new table
            let tableHtml = '<b>IN CENTIMETER</b>\n<table class="size-table">\n<thead>' + html.match(/<thead>(.*?)<\/thead>/)[1] + '</thead>\n<tbody>';
            let inchTableHtml = '<b>IN INCH</b>\n<table class="size-table">\n<thead>' + html.match(/<thead>(.*?)<\/thead>/)[1] + '</thead>\n<tbody>';

            const rows = html.match(/<tr>(.*?)<\/tr>/g);
            rows.shift(); // Remove header row
            rows.forEach(row => {
                let cells = row.match(/<td>(.*?)<\/td>/g);
                tableHtml += '<tr>';
                inchTableHtml += '<tr>';
                cells.forEach(cell => {
                    let value = cell.replace(/<td>|<\/td>/g, '').trim();
                    if (!isNaN(value)) {
                        let inchValue = (Math.ceil(parseFloat(value) * 0.393701 * 10) / 10).toFixed(2) + '"';
                        inchTableHtml += `<td>${inchValue}</td>`;
                        tableHtml += `<td>${value}</td>`;
                    } else {
                        let sizePrefix = '';
                        Object.keys(sizeMap).forEach(sizeKey => {
                            if (sizeMap[sizeKey] === value) {
                                sizePrefix = sizeKey + ' - ';
                            }
                        });
                        inchTableHtml += `<td>${sizePrefix}${value}</td>`;
                        tableHtml += `<td>${sizePrefix}${value}</td>`;
                    }
                });
                tableHtml += '</tr>\n';
                inchTableHtml += '</tr>\n';
            });
            tableHtml += '</tbody>\n</table>';
            inchTableHtml += '</tbody>\n</table>';

            return tableHtml + '\n<br>\n<br>\n' + inchTableHtml;
        };

        const sizeElements = document.querySelectorAll('.size_text_');
        const sizeTranslations = {
            'フリー': 'One Size',
            'インチ': 'Inch'
        };

        let sizeSet = new Set();
        let sizeMap = {};
        sizeElements.forEach(el => {
            let sizeText = el.innerText.trim();
            Object.keys(sizeTranslations).forEach(key => {
                sizeText = sizeText.replace(key, sizeTranslations[key]);
            });
            sizeText = sizeText.replace('-', ' - ');
            sizeSet.add(sizeText);

            const sizeIdentifier = sizeText.split(' - ')[0];
            const sizeValue = sizeText.split(' - ')[1];
            sizeMap[sizeIdentifier] = sizeValue;
        });
        let size = Array.from(sizeSet).join(', ');

        sizeChartHtml = translateAndFormatSizeChart(sizeChartHtml, sizeMap);

        // More details (raw HTML)
        let moreDetailsTextElement = document.querySelector('.detail_block_');
        let moreDetailsTextHTML = moreDetailsTextElement ? moreDetailsTextElement.innerHTML : 'N/A';

        // Log the moreDetailsTextHTML content
        console.log('Extracted moreDetailsTextHTML:', moreDetailsTextHTML);

        // Function to replace specific indigo care notes and other care instructions
        const replaceIndigoCareNote = (html) => {
            const indigoCareNote1 = '<div class="detail_attention_"> <p><br> ※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a><br><br><br></p> </div>';
            const indigoCareNote2 = '<font color="red"> ※92-クロについては別布としてインディゴ生地を使用しており移染の可能性がございますのでご注意ください。</font>藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a>';
            const indigoCareNote3 = '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br><br></p> </div>';
            const indigoCareNote4 = '<div class="detail_attention_"> <p><br> ※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a><br></p> </div>';
            const indigoCareNote5 = '<div class="detail_attention_"> <p><br> ※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a><br>';
            const indigoCareNote6 = '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br><br><br></p> </div>';
            const indigoCareNote7 = '※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a>';
            const indigoCareNote8 = '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br></p> </div>';
            const indigoCareNote9 = '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br></p> </div> ';
            const indigoCareNote10 = '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br>';
            const indigoCareNote11 = '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br></div>';
            const dryCleaningNote = '<div class="detail_attention_"> <p>※ドライクリーニングのみ<br><br><br></p> </div>';
            const dryCleaningNote1 = '<div class="detail_attention_"> <p>※ドライクリーニングのみ<br><br> </div>';
            const dryCleaningNote2 = '<div class="detail_attention_"> <p>※ドライクリーニングのみ<br></p> </div>';
            const dryCleaningNote3 = '<div class="detail_attention_"> <p>※ドライクリーニングのみ<br> <br>';
            const dryCleaningNote4 = '<div class="detail_attention_"> <p>※ドライクリーニングのみ<br><br>';
            const dryCleaningNote5 = '※ドライクリーニングのみ<br></p>';
            const indigoNote = '※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a><br><br><br></p>';
            const bandNote = '<div class="detail_attention_"> <p>※ウエストゴム入り<br><br><br></p> </div>';
            const bandNote1 = '※ウエストゴム入り';
            const supergauze = '<div class="detail_attention_"> <p>※超ガーゼ製品のお手入れ方法は<a href="https://shop.45r.jp/shop/pages/help.aspx#cottonknit_care_"><font color="navy">こちら</font></a><br><br>';
            const supergauze1 = '<div class="detail_attention_"> <p><br>※超ガーゼ製品のお手入れ方法は<a href="https://shop.45r.jp/shop/pages/help.aspx#cottonknit_care_"><font color="navy">こちら</font></a><br><br>';
            const supergauze2 =  '<div class="detail_attention_"> <p><br>※超ガーゼ製品のお手入れ方法は<a href="https://shop.45r.jp/shop/pages/help.aspx#cottonknit_care_"><font color="navy">こちら</font></a><br><br> <br><br>';
            const shrinkNote = '<div class="detail_attention_"> <p>※縮絨加工を施しておりますため、<br> 1点1点縮み具合に若干の誤差がございます。<br>';

  
            const newIndigoCareNote = `<div class="detail-note">The color gently fades over time due to the natural characteristics unique to indigo dye. Please wash by itself or with similar colors. Cherish your indigo products just like our beloved bunny friend, and enjoy them while being mindful of the following points of caution. <br><br><img src="https://cdn.shopify.com/s/files/1/0666/5089/8714/files/Indigo_Care.jpg"></div>`;
            const newDryCleaningNote = `<div class="detail-note"> <p>DRY CLEANING ONLY<br></p> </div>`;
            const newBandNote = `<div class="detail-note"> <p>ELASTIC WAISTBAND<br></p> </div>`;
            const supergauzenote = `<div class="detail-note">Due to the delicate nature of this product made with fine yarn, please handle with care. Avoid snagging, pulling, or stretching.</div>`;
            const newshrinkNote = `<div class="detail-note"> <p>Due to the shrinking process, <br> there may be slight differences in the degree of shrinkage for each item.<br></p> </div>`;
  
            // Replace the specific indigo care notes with the new note
            html = html.replace(new RegExp(indigoCareNote1, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote2, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote3, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote4, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote5, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote6, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote7, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote8, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote9, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote10, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoCareNote11, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(indigoNote, 'g'), newIndigoCareNote);
            html = html.replace(new RegExp(bandNote, 'g'), newBandNote);
            html = html.replace(new RegExp(bandNote1, 'g'), newBandNote);
            html = html.replace(new RegExp(supergauze, 'g'), supergauzenote);
            html = html.replace(new RegExp(supergauze1, 'g'), supergauzenote);
            html = html.replace(new RegExp(supergauze2, 'g'), supergauzenote);
            html = html.replace(new RegExp(shrinkNote, 'g'), newshrinkNote);
  
            // Replace the dry cleaning note with the new note
            html = html.replace(new RegExp(dryCleaningNote, 'g'), newDryCleaningNote);
            html = html.replace(new RegExp(dryCleaningNote1, 'g'), newDryCleaningNote);
            html = html.replace(new RegExp(dryCleaningNote2, 'g'), newDryCleaningNote);
            html = html.replace(new RegExp(dryCleaningNote3, 'g'), newDryCleaningNote);
            html = html.replace(new RegExp(dryCleaningNote4, 'g'), newDryCleaningNote);
            html = html.replace(new RegExp(dryCleaningNote5, 'g'), newDryCleaningNote);
  
            return html;
        };

        // Function to check for "super gauze" in description and add care note if needed
        const addCareNoteForSuperGauze = (description, moreDetailsTextHTML) => {
            // Define the "super gauze" care note
            const superGauzeCareNote = `<div class="detail-note">Due to the delicate nature of this product made with fine yarn, please handle with care. Avoid snagging, pulling, or stretching.</div>`;
  
           // Define what constitutes an Indigo Care Note in moreDetails
            const indigoCareNoteIdentifier = 'The color gently fades over time due to the natural characteristics unique to indigo dye.';
  
            // Check if "super gauze" is in the description
            const hasSuperGauze = description.toLowerCase().includes("super gauze");
  
            // Check if moreDetails already contains an Indigo Care Note
            const hasIndigoCareNote = moreDetailsTextHTML.includes(indigoCareNoteIdentifier);
  
            // Check if the Super Gauze care note has already been added
            const hasSuperGauzeCareNote = moreDetailsTextHTML.includes(superGauzeCareNote);
  
            // Add the Super Gauze care note only if "super gauze" is in the description,
            // there is no Indigo Care Note, and the Super Gauze note hasn't already been added
            if (hasSuperGauze && !hasIndigoCareNote && !hasSuperGauzeCareNote) {
                // Clean up any empty or redundant "detail-note" divs
                moreDetailsTextHTML = moreDetailsTextHTML.replace(/<div class="detail-note">\s*<\/div>/g, '');
        
                // Append the Super Gauze care note
                moreDetailsTextHTML += superGauzeCareNote;
            }
  
            return moreDetailsTextHTML;
        };


        // Remove unwanted text in moreDetails
        const removeUnwantedJapaneseText = (html) => {
          const unwantedTexts = [
              '<div class="detail_attention_"> <p><br> ※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a><br><br><br></p> </div>',
              '<font color="red"> ※92-クロについては別布としてインディゴ生地を使用しており移染の可能性がございますのでご注意ください。</font>藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a>',
              '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br><br></p> </div>',
              '<div class="detail_attention_"> <p>※ドライクリーニングのみ<br><br><br></p> </div>',
              '<div class="detail_attention_"> <p><br> ※インディゴ製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#aiindigo_care_"><font color="navy">こちら</font></a><br>',
              '<div class="detail_attention_"> <p>※藍染め製品のため、<br> 移染する可能性がございます。<br> 藍・インディゴ製品のお手入れ方法は<a href="https://45ronlinestore.jp/shop/pages/help.aspx#ai_care_"><font color="navy">こちら</font></a><br><br><br><br></p> </div>',
              '<div class="detail_attention_"> <p>※超ガーゼ製品のお手入れ方法は<a href="https://shop.45r.jp/shop/pages/help.aspx#cottonknit_care_"><font color="navy">こちら</a></font><br><br></p></div>'
          ];

          unwantedTexts.forEach(unwantedText => {
              html = html.replace(new RegExp(unwantedText, 'g'), '').trim();
          });

          return html;
        };

        // Clean up redundant HTML
        const cleanUpRedundantHtml = (html) => {
            // Remove duplicated or redundant '生産国・素材' sections
            html = html.replace(/<div class="detail_text_">.*?<\/div>\s*<div class="detail_text_">/g, '<div class="detail_text_">');
  
            // Handle any potential tag truncations (e.g., missing content)
            html = html.replace(/<div class="detail_title_">\s*生産国・素材\s*<\/div>/, '');
  
            // Replace the specific div structure with <div class="detail-info">
            html = html.replace(/<div class="detail_title_">\s*国・素材\s*<\/div>\s*<div class="detail_text_">/, '<div class="detail-info">');
  
            // Remove iframe section
            html = html.replace(/<iframe.*?<\/iframe>/g, '');
  
            // Replace specific Japanese phrases with English translations
            html = translateJapaneseToEnglish(html);
  
            // Replace dynamic material percentages
            html = replaceMaterialPercentages(html);
  
            // Remove specific HTML tags and replace </dd> with <br>
            html = removeSpecificHtmlTags(html);
  
            return html;
        };

        // Function to replace Japanese phrases with English translations
        const translateJapaneseToEnglish = (html) => {
          const translations = {
              '商品番号：': 'PRODUCT NUMBER：',
              '生産国：': 'COUNTRY ORIGIN：',
              '素材：': 'MATERIAL：',
              '別布': ', OTHER FABRIC：',
              '中綿': ', FILLING：',
              '表地': 'OUTER：',
              '裏地': ', LINING：',
              '袖裏': ', SLEEVE LINING：',
              '金属部分': ', METAL PART：',
              '前身頃': 'FRONT：',
              '後見頃': 'BACK：',
              '部分使い 馬革': ', PARTIALLY USED HORSE LEATHER',
              '本体': 'BODY',
              '襟': 'COLLAR：'
          };

          Object.keys(translations).forEach(japanese => {
              const english = translations[japanese];
              html = html.replace(new RegExp(japanese, 'g'), english);
          });

          return html;
        };

        // Function to dynamically replace material percentages and handle exact matches
        const replaceMaterialPercentages = (html) => {
            // Translation dictionary for materials
            const materialTranslations = {
                'コットン': 'COTTON',
                '綿': 'COTTON',
                'ポリクラール': 'POLYCLAR',
                'ポリエステル': 'POLYESTER',
                'ポリウレタン': 'POLYURETHANE',
                'ウール': 'WOOL',
                '毛': 'WOOL',
                'リネン': 'LINEN',
                '麻': 'LINEN',
                'シルク': 'SILK',
                'カシミヤ': 'CASHMERE',
                'カシミア': 'CASHMERE',
                'アルパカ': 'ALPACA',
                'シルバー': 'SILVER',
                'ヘンプ': 'HEMP',
                'レーヨン': 'RAYON',
                'ナイロン': 'NYLON',
                'アクリル': 'ACRYLIC',
                '錫合': 'MIXTURE OF TIN & COPPER',
                '牛革 バックル 真鍮': 'COWHIDE LEATHER BUCKLE BRASS',
                '亜鉛': 'ZINC',
                '羊革': 'SHEEPSKIN',
                '真鍮': 'BRASS'
            };

            // Handle both full-width and half-width percentage signs
            const percentPattern = '[0-9０-９]+[%％]?';

            // Regex to match materials followed optionally by a percentage or additional descriptions
            const materialRegex = new RegExp(`(${Object.keys(materialTranslations).join('|')})(\\s*${percentPattern})?(\\s*(金属部分|バックル|部分)\\s*\\w*)?`, 'g');

            // Replace each match with the translated material and formatted percentage
            return html.replace(materialRegex, (match, material, percentage = '', additionalDesc = '') => {
                const englishMaterial = materialTranslations[material.trim()] || material;
                const englishAdditionalDesc = additionalDesc.trim() ? ` ${materialTranslations[additionalDesc.trim()] || additionalDesc.trim()}` : '';
                const formattedPercentage = percentage ? percentage.replace('％', '%') : '';
                return `${formattedPercentage} ${englishMaterial}${englishAdditionalDesc}`.trim();
            });
        };


        // Function to remove specific HTML tags and replace </dd> with <br>
        const removeSpecificHtmlTags = (html) => {
          const tagsToRemove = [
              '</dt> <dd>', '<dl>', '<dt>', '</dl>', '  ', '   ', '</div></p>', '</div><br><br><br></p>', '</div><br></p>', '</div><br><br> </p>', '</div><br><br><br> </p>', '</div><br> ',
          ];

          // Remove specified tags
          tagsToRemove.forEach(tag => {
              html = html.replace(new RegExp(tag, 'g'), '');
          });

          // Replace </dd> with <br>
          html = html.replace(/<\/dd>/g, '<br>');
          html = html.replace(/<\/div><\/div>/g, '</div>');

          // Replace <div class="detail_attention_"> <p><br><br></p> </div> with <div class="detail-note"></div>
          html = html.replace(/<div class="detail_attention_"> <p><br><br><\/p> <\/div>/g, '<div class="detail-note"></div>');
          html = html.replace(/<div class="detail_attention_"> <p><\/p> <\/div>/g, '<div class="detail-note"></div>');
          html = html.replace(/<div class="detail_text_">/g, '<div class="detail-info">');
          

          return html;
        };

        // Extract modeling info
        let modeling = '';

        // Use a more flexible regex to capture multiple model heights and sizes in the same block, including fractional Inch sizes like "40.5 Inch"
        const modelingMatches = moreDetailsTextHTML.match(/モデル身長(\d+cm)<br>着用サイズ(?:00-)?(\d{2})-(\d+(?:\.\d+)?インチ|フリー|[A-Z]+)/g);

        if (modelingMatches) {
        modeling = modelingMatches.map(match => {
                const modelHeight = match.match(/モデル身長(\d+)cm/)[1];
                const sizeNumber = match.match(/着用サイズ(?:00-)?(\d{2})/)[1];
                const sizeLabel = match.match(/-(\d+(?:\.\d+)?インチ|フリー|[A-Z]+)/)[1];

                // Convert the height from cm to feet and inches
                const heightInFeet = (parseInt(modelHeight) * 0.0328084).toFixed(2);
                const feet = Math.floor(heightInFeet);
                const inches = Math.round((heightInFeet - feet) * 12);

                // Return the formatted string
                return `MODEL HEIGHT ${modelHeight}cm (${feet}’${inches}”)<br>WEARING SIZE ${sizeNumber} - ${sizeLabel}`;
            }).join(' <br> ');

            // Remove the extracted modeling info from the original HTML
                    modelingMatches.forEach(match => {
                moreDetailsTextHTML = moreDetailsTextHTML.replace(new RegExp(match, 'g'), '').trim();
            });
        }

        // Function to insert the modeling info into the size chart
        const insertModelingInfoToSizeChart = (sizeChartHtml, modeling) => {
            const sizeMap = new Map();

            // Extract the size numbers and labels from the size chart
            const sizeChartRows = sizeChartHtml.match(/<td>(\d{2}) - ([^<]+)<\/td>/g);
            if (sizeChartRows) {
                sizeChartRows.forEach(row => {
                    const sizeNumber = row.match(/<td>(\d{2})/)[1];
                    const sizeLabel = row.match(/ - ([^<]+)/)[1];
                    sizeMap.set(sizeNumber, sizeLabel);
                });
            }

            // Replace the size numbers in the modeling info to match the size chart format
            modeling = modeling.replace(/WEARING SIZE (\d{2}) - ([^<]+)/g, (match, sizeNumber, sizeLabel) => {
                if (sizeMap.has(sizeNumber)) {
                    return `WEARING SIZE ${sizeNumber} - ${sizeMap.get(sizeNumber)}`;
                }
                return match;
            });

            // Append modeling info to the size chart if it exists
            if (modeling) {
                sizeChartHtml += `<br><br><div class="detail-material">${modeling}</div>`;
            }

            return sizeChartHtml;
        };

        // Format modeling info to convert height from cm to feet and inches and replace "フリー" with "One Size"
        modeling = modeling
        .replace(/モデル身長(\d+)cm/g, (match, p1) => {
            const heightInFeet = (parseInt(p1) * 0.0328084).toFixed(2);
           const feet = Math.floor(heightInFeet);
            const inches = Math.round((heightInFeet - feet) * 12);
            return `MODEL HEIGHT ${p1}cm (${feet}’${inches}”)`;
        })
        .replace(/着用サイズ(?:00-)?(\d+|フリー)(?:\s*-\s*([A-Z]+))?/g, (match, p1, p2) => {
            let suffix = p2 ? ` - ${p2}` : '';
            return `WEARING SIZE ${p1}${suffix}`;
        })
        .replace(/フリー/g, 'One Size')  // Replace "フリー" with "One Size"
        .replace(/インチ/g, 'Inch');


        // Clean up redundant HTML and spaces
        modeling = modeling.replace(/\n\s*/g, ' ').trim();
        moreDetailsTextHTML = moreDetailsTextHTML.replace(/\n\s*/g, ' ').trim();

        // Replace specific attention note with new content in the "moreDetailsTextHTML"
        moreDetailsTextHTML = replaceIndigoCareNote(moreDetailsTextHTML);

        // Remove unwanted Japanese text from "moreDetailsTextHTML"
        moreDetailsTextHTML = removeUnwantedJapaneseText(moreDetailsTextHTML);

        // Clean up redundant HTML elements in the "moreDetailsTextHTML"
        moreDetailsTextHTML = cleanUpRedundantHtml(moreDetailsTextHTML);

        // Add the Super Gauze care note if necessary
        moreDetailsTextHTML = addCareNoteForSuperGauze(description, moreDetailsTextHTML);

        // Collect all sizes from size, sizeChart, and modeling
        const sizeOrder = ['One Size', 'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '26Inch', '27Inch', '28Inch', '29Inch', '30Inch', '31Inch', '32Inch', '33Inch', '34Inch', '36Inch'];
        const collectedSizes = new Set();

        // Collect sizes from size
        const sizeList = size ? size.split(', ').map(s => s.split(' - ')[1]).filter(s => s !== undefined) : [];
        sizeList.forEach(s => collectedSizes.add(s));

        // Collect sizes from sizeChart
        const sizeChartSizes = sizeChartHtml ? sizeChartHtml.match(/<td>(XS|S|M|L|XL|XXS|XXL|One Size|\d+Inch)<\/td>/g)?.map(td => td.replace(/<td>|<\/td>/g, '').trim()).filter(s => s !== undefined) : [];
        if (sizeChartSizes) {
            sizeChartSizes.forEach(s => collectedSizes.add(s));
        }

        // Collect sizes from modeling
        const modelingSizes = modeling ? modeling.match(/WEARING SIZE \d+ - (\w+)/g)?.map(ms => ms.split(' - ')[1]).filter(s => s !== undefined) : [];
        if (modelingSizes) {
            modelingSizes.forEach(s => collectedSizes.add(s));
        }

        // Remove duplicates and sort sizes
        const uniqueSizes = Array.from(collectedSizes).filter(size => size !== 'Size').sort((a, b) => {
            const indexA = sizeOrder.indexOf(a);
            const indexB = sizeOrder.indexOf(b);
            return indexA - indexB;
        });

        // Generate initial numbering based on size return
        const numberingMap = new Map();
        size.split(', ').forEach(s => {
            const prefix = s.split(' - ')[0];
            const sizeValue = s.split(' - ')[1];
            numberingMap.set(sizeValue, parseInt(prefix));
        });

        // Initialize final numbering map with undefined values
        const finalNumberingMap = new Map();
        uniqueSizes.forEach(size => {
            if (numberingMap.has(size)) {
                finalNumberingMap.set(size, numberingMap.get(size));
            } else {
                finalNumberingMap.set(size, NaN);
            }
        });

        // Fill missing numbers based on relative positions
        uniqueSizes.forEach((size, index) => {
            if (isNaN(finalNumberingMap.get(size))) {
                let prevIndex = index - 1;
                let nextIndex = index + 1;

                while (prevIndex >= 0 && isNaN(finalNumberingMap.get(uniqueSizes[prevIndex]))) prevIndex--;
                while (nextIndex < uniqueSizes.length && isNaN(finalNumberingMap.get(uniqueSizes[nextIndex]))) nextIndex++;

                if (prevIndex >= 0 && nextIndex < uniqueSizes.length) {
                    const prevNumber = finalNumberingMap.get(uniqueSizes[prevIndex]);
                    const nextNumber = finalNumberingMap.get(uniqueSizes[nextIndex]);
                    finalNumberingMap.set(size, prevNumber + (index - prevIndex));
                } else if (prevIndex >= 0) {
                    const prevNumber = finalNumberingMap.get(uniqueSizes[prevIndex]);
                    finalNumberingMap.set(size, prevNumber + (index - prevIndex));
                } else if (nextIndex < uniqueSizes.length) {
                    const nextNumber = finalNumberingMap.get(uniqueSizes[nextIndex]);
                    finalNumberingMap.set(size, nextNumber - (nextIndex - index));
                }
            }
        });

        // Convert final numbering map to array and sort
        const numbering = Array.from(finalNumberingMap.entries()).sort((a, b) => a[1] - b[1]).map(([size, number]) => `${number.toString().padStart(2, '0')} - ${size}`);

        // Replace sizes in sizeChart with the information in numbering
        numbering.forEach(item => {
            const [number, size] = item.split(' - ');
            sizeChartHtml = sizeChartHtml.replace(new RegExp(`>${size}<`, 'g'), `>${number} - ${size}<`);
        });

        /* Returning an object filled with the scraped data */
        // Append modeling info here to the final size chart to ensure it’s added only once
        let finalSizeChartHtml = sizeChartHtml;
        if (modeling) {
            finalSizeChartHtml += `<br><br><div class="detail-material">${modeling}</div>`;
        }

        return {
            productId,
            description,
            sizeChart: finalSizeChartHtml + `<br> <p class="size-note"> Please note that the sizes listed above are standard.<br> There may be a slight size deviation depending on the product. Please refer the size chart shown below.<br><br><img src="https://cdn.shopify.com/s/files/1/0666/5089/8714/files/Size_Guide.png"></p>`,
            moreDetails: moreDetailsTextHTML
        };
    }, productId);

    await browser.close();
    return data;
}

app.get('/scrape/:productIds', async (req, res) => {
    try {
        const productIds = req.params.productIds.split(',');
        const productInfoPromises = productIds.map(productId => scrapeProductInfo(productId.trim()));
        const productsInfo = await Promise.all(productInfoPromises);

        res.setHeader('Content-Type', 'text/html');
        const htmlResponse = `
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/themes/prism.min.css" rel="stylesheet" />
                <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/prism.min.js"></script>
                <style>
                    body { font-family: 'Courier New', monospace; background-color: #333; color: #f4f4f9; margin: 0; padding: 20px; }
                    pre { background-color: #1e1e1e; padding: 20px; border-radius: 8px; overflow: auto; white-space: pre-wrap; }
                    code { color: #f4f4f9; }
                    button { margin: 10px 0; background-color: #555; color: white; border: none; padding: 8px 12px; cursor: pointer; }
                    button:hover { background-color: #777; }
                </style>
            </head>
            <body>
                ${productsInfo.map(info => `
                    <h3>Product Info for ${info.productId}</h3>
                    <button onclick="copyToClipboard('code-${info.productId}')">Copy Code</button>
                    <pre><code id="code-${info.productId}" class="language-html">
<b>IN CENTIMETER</b>${escapeHTML(info.sizeChart)}<br><br>
<b>Description:</b><br>${escapeHTML(info.description)}<br><br>
<b>More Details:</b><br>${escapeHTML(info.moreDetails)}<br><br>
                    </code></pre>
                `).join('')}
                <script>
                    function copyToClipboard(elementId) {
                        const codeElement = document.getElementById(elementId);
                        const range = document.createRange();
                        range.selectNode(codeElement);
                        window.getSelection().removeAllRanges();
                        window.getSelection().addRange(range);
                        document.execCommand('copy');
                        window.getSelection().removeAllRanges();
                        alert('Code copied to clipboard');
                    }
                </script>
            </body>
            </html>
        `;
        res.send(htmlResponse);
    } catch (error) {
        console.error('Scraping failed:', error);
        res.status(500).send('Failed to retrieve product data');
    }
});

function escapeHTML(text) {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;')
        .replace(/\n/g, '<br>')  // Ensures newlines are preserved
        .replace(/\s\s+/g, '&nbsp;&nbsp;'); // Preserves multiple spaces
}

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
