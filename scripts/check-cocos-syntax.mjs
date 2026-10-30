import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import ts from "typescript";

const directory = "assets/scripts";
const files = readdirSync(directory).filter((name) => name.endsWith(".ts")).sort();
if (files.length === 0) throw new Error("No Cocos TypeScript components found.");
let errors = 0;
for (const name of files) {
  const fileName = join(directory, name);
  const result = ts.transpileModule(readFileSync(fileName, "utf8"), {
    fileName,
    reportDiagnostics: true,
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.ESNext,
      experimentalDecorators: true,
      useDefineForClassFields: false
    }
  });
  for (const diagnostic of result.diagnostics ?? []) {
    if (diagnostic.category !== ts.DiagnosticCategory.Error) continue;
    errors++;
    const message = ts.flattenDiagnosticMessageText(diagnostic.messageText, "\\n");
    process.stderr.write(fileName + ": " + message + "\\n");
  }
}
if (errors) process.exit(1);
console.log("PASS: TypeScript syntax transpilation for " + files.length + " Cocos scripts. This is not an engine type-check or Editor build.");
