import { defineConfig } from "vitest/config";
import path from "node:path";
export default defineConfig({test:{environment:"node",setupFiles:["./tests/setup.ts"],include:["tests/unit/**/*.test.ts"],exclude:["tests/e2e/**","outputs/**","node_modules/**"],coverage:{reporter:["text","html"]}},resolve:{alias:{"@":path.resolve(import.meta.dirname,"./src"),"server-only":path.resolve(import.meta.dirname,"./tests/stubs/server-only.ts")}}});
