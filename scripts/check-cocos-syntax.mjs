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
  const sourceFile = ts.createSourceFile(fileName, readFileSync(fileName, "utf8"), ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const visit = (node) => {
    if (ts.isClassDeclaration(node) || ts.isClassExpression(node)) {
      const seen = new Map();
      for (const member of node.members) {
        const key = member.name && (ts.isIdentifier(member.name) || ts.isStringLiteral(member.name) || ts.isNumericLiteral(member.name)) ? member.name.text : null;
        if (key === null) continue;
        if (seen.has(key)) {
          errors++;
          process.stderr.write(fileName + ": duplicate class member \"" + key + "\" (lines " + seen.get(key) + " and " + sourceFile.getLineAndCharacterOfPosition(member.getStart(sourceFile)).line + 1 + ")\\n");
        } else seen.set(key, sourceFile.getLineAndCharacterOfPosition(member.getStart(sourceFile)).line + 1);
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  for (const diagnostic of result.diagnostics ?? []) {
    if (diagnostic.category !== ts.DiagnosticCategory.Error) continue;
    errors++;
    const message = ts.flattenDiagnosticMessageText(diagnostic.messageText, "\\n");
    process.stderr.write(fileName + ": " + message + "\\n");
  }
}
if (errors) process.exit(1);
console.log("PASS: TypeScript syntax transpilation for " + files.length + " Cocos scripts. This is not an engine type-check or Editor build.");
