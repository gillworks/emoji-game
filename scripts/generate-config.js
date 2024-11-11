const fs = require("fs");
require("dotenv").config({ path: ".env.local" });

const config = {
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
};

const fileContent = `window.env = ${JSON.stringify(config, null, 2)};`;

fs.writeFileSync("config.js", fileContent);
console.log("config.js generated successfully");
