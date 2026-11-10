import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createApp} from '../server.mjs';

test('account page shows sign-in and hides in-game features',{skip:!process.env.FG_TEST_PLAYWRIGHT||!process.env.FG_TEST_BROWSER},async t=>{
 const {chromium}=await import(pathToFileURL(process.env.FG_TEST_PLAYWRIGHT).href);
 const directory=await mkdtemp(path.join(os.tmpdir(),'fai-login-ui-'));
 const app=await createApp({directory,persistent:false});
 const browser=await chromium.launch({executablePath:process.env.FG_TEST_BROWSER,headless:true});
 t.after(async()=>{await browser.close();await app.close();await rm(directory,{recursive:true,force:true});});
 const page=await browser.newPage();const errors=[];page.on('pageerror',error=>errors.push(error.message));
 await page.goto(app.origin+'/#launch='+app.launch);
 await page.waitForFunction(()=>document.querySelector('#provider').options.length>0);
 assert(await page.locator('#provider').isVisible());
 assert(await page.locator('#credentialState').isVisible());
 assert(!(await page.locator('#question').isVisible()));
 assert(!(await page.locator('#model').isVisible()));
 await page.selectOption('#provider','gemini');
 assert(await page.locator('#apiKey').isVisible());
 assert.deepEqual(errors,[]);
});
