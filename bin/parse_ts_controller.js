#!/usr/bin/env node
/* eslint-disable */

const ts = require('typescript');
const fs = require('fs');

// Get filename from command line argument
const filename = process.argv[2];

if (!filename) {
  console.error('Usage: node parse_ts_controller.js <filename>');
  process.exit(1);
}

const sourceCode = fs.readFileSync(filename, 'utf8');

// Create TypeScript AST
const sourceFile = ts.createSourceFile(
  filename,
  sourceCode,
  ts.ScriptTarget.Latest,
  true // setParentNodes
);

const result = {
  targets: [],
  optionalTargets: [],
  outlets: [],
  values: [],
  valuesWithDefaults: [],
  methods: [],
  querySelectors: [],
  antiPatterns: [],
  targetsWithSkip: [],
  valuesWithSkip: [],
  isSystemController: false
};

// Helper function to extract string literals from array
function extractArrayStringLiterals(node) {
  const items = [];

  if (ts.isArrayLiteralExpression(node)) {
    node.elements.forEach(element => {
      if (ts.isStringLiteral(element)) {
        items.push(element.text);
      }
    });
  }

  return items;
}

// Helper function to extract value names and check for defaults
function extractValuesWithDefaults(node) {
  const values = [];
  const valuesWithDefaults = [];

  if (ts.isObjectLiteralExpression(node)) {
    node.properties.forEach(prop => {
      if (ts.isPropertyAssignment(prop) && ts.isIdentifier(prop.name)) {
        const valueName = prop.name.text;
        values.push(valueName);

        // Check if value definition has a default property
        if (ts.isObjectLiteralExpression(prop.initializer)) {
          const hasDefault = prop.initializer.properties.some(innerProp => {
            return ts.isPropertyAssignment(innerProp) &&
                   ts.isIdentifier(innerProp.name) &&
                   innerProp.name.text === 'default';
          });

          if (hasDefault) {
            valuesWithDefaults.push(valueName);
          }
        }
      }
    });
  }

  return { values, valuesWithDefaults };
}

// Helper function to check for preventDefault + requestSubmit anti-pattern
function checkAntiPatterns(methodBody, methodName) {
  let hasPreventDefault = false;
  let hasRequestSubmit = false;
  let preventDefaultLine = null;
  let requestSubmitLine = null;

  function traverse(node) {
    // Check for preventDefault() call
    if (ts.isCallExpression(node) &&
        ts.isPropertyAccessExpression(node.expression) &&
        node.expression.name.text === 'preventDefault') {
      hasPreventDefault = true;
      preventDefaultLine = sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1;
    }

    // Check for requestSubmit() call
    if (ts.isCallExpression(node) &&
        ts.isPropertyAccessExpression(node.expression) &&
        node.expression.name.text === 'requestSubmit') {
      hasRequestSubmit = true;
      requestSubmitLine = sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1;
    }

    ts.forEachChild(node, traverse);
  }

  traverse(methodBody);

  if (hasPreventDefault && hasRequestSubmit) {
    result.antiPatterns.push({
      type: 'preventDefault + requestSubmit',
      method: methodName,
      line: requestSubmitLine,
      issue: 'preventDefault() blocks form submission, making requestSubmit() ineffective'
    });
  }
}

// Helper function to check if a node has skip validation comment
function checkSkipComment(node) {
  // Get the statement or expression statement that contains this call
  let statement = node;
  while (statement.parent && !ts.isExpressionStatement(statement.parent) && !ts.isVariableStatement(statement.parent)) {
    statement = statement.parent;
  }

  if (statement.parent) {
    statement = statement.parent;
  }

  // Get the full text range including trivia (comments)
  const fullStart = statement.getFullStart();
  const start = statement.getStart(sourceFile);

  // Get the text between fullStart and start (this contains leading trivia/comments)
  const triviaText = sourceCode.substring(fullStart, start);

  // Check for stimulus-validator: disable-next-line comment
  if (triviaText.includes('stimulus-validator: disable-next-line')) {
    return true;
  }

  return false;
}

// Helper function to check if a property declaration has skip validation comment
function checkPropertySkipComment(node) {
  // For property declarations, we can directly check the node's leading trivia
  const fullStart = node.getFullStart();
  const start = node.getStart(sourceFile);

  // Get the text between fullStart and start (this contains leading trivia/comments)
  const triviaText = sourceCode.substring(fullStart, start);

  // Check for stimulus-validator: disable-next-line comment
  if (triviaText.includes('stimulus-validator: disable-next-line')) {
    return true;
  }

  return false;
}

// Helper function to extract querySelector calls
function extractQuerySelectors(node, methodName = null) {
  if (ts.isCallExpression(node)) {
    // Check if it's this.element.querySelector or this.element.querySelectorAll
    if (ts.isPropertyAccessExpression(node.expression)) {
      const propAccess = node.expression;
      const methodCall = propAccess.name.text;

      if (methodCall === 'querySelector' || methodCall === 'querySelectorAll') {
        // Check if it's this.element.querySelector
        if (ts.isPropertyAccessExpression(propAccess.expression)) {
          const elementAccess = propAccess.expression;
          if (elementAccess.name.text === 'element' &&
              elementAccess.expression.kind === ts.SyntaxKind.ThisKeyword) {

            // Extract the selector argument
            if (node.arguments.length > 0) {
              const selectorArg = node.arguments[0];
              const skipValidation = checkSkipComment(node);

              if (ts.isStringLiteral(selectorArg)) {
                result.querySelectors.push({
                  selector: selectorArg.text,
                  method: methodCall,
                  inMethod: methodName,
                  line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1,
                  skipValidation: skipValidation
                });
              } else if (ts.isTemplateExpression(selectorArg) || ts.isNoSubstitutionTemplateLiteral(selectorArg)) {
                // Handle template literals
                const selectorText = selectorArg.getText(sourceFile);
                result.querySelectors.push({
                  selector: selectorText,
                  method: methodCall,
                  inMethod: methodName,
                  line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1,
                  isTemplate: true,
                  skipValidation: skipValidation
                });
              }
            }
          }
        }
      }
    }
  }

  // Continue traversing child nodes
  ts.forEachChild(node, child => extractQuerySelectors(child, methodName));
}

// Traverse AST to find class members
function visitNode(node) {
  // Look for class declaration
  if (ts.isClassDeclaration(node)) {
    // Check for system-controller comment on class
    const fullStart = node.getFullStart();
    const start = node.getStart(sourceFile);
    const triviaText = sourceCode.substring(fullStart, start);
    if (triviaText.includes('stimulus-validator: system-controller')) {
      result.isSystemController = true;
    }

    node.members.forEach(member => {
      // Check for static properties
      if (ts.isPropertyDeclaration(member) &&
          member.modifiers?.some(m => m.kind === ts.SyntaxKind.StaticKeyword)) {

        const name = member.name.getText(sourceFile);

        // Extract static targets = [...]
        if (name === 'targets' && member.initializer) {
          result.targets = extractArrayStringLiterals(member.initializer);
        }

        // Extract static outlets = [...]
        if (name === 'outlets' && member.initializer) {
          result.outlets = extractArrayStringLiterals(member.initializer);
        }

        // Extract static values = {...}
        if (name === 'values' && member.initializer) {
          const valuesData = extractValuesWithDefaults(member.initializer);
          result.values = valuesData.values;
          result.valuesWithDefaults = valuesData.valuesWithDefaults;
        }
      }

      // Check for readonly property declarations to find optional targets and values with skip
      if (ts.isPropertyDeclaration(member) &&
          member.modifiers?.some(m => m.kind === ts.SyntaxKind.ReadonlyKeyword)) {

        const propertyName = member.name.getText(sourceFile);
        const hasSkipComment = checkPropertySkipComment(member);

        // Check if it's a hasXXXTarget property
        const hasTargetMatch = propertyName.match(/^has(\w+)Target$/);
        if (hasTargetMatch) {
          // Convert hasMenuTarget -> menu
          const targetName = hasTargetMatch[1].charAt(0).toLowerCase() + hasTargetMatch[1].slice(1);
          result.optionalTargets.push(targetName);
        }

        // Check if it's a declare readonly xxxTarget property
        const targetMatch = propertyName.match(/^(\w+)Target$/);
        if (targetMatch && hasSkipComment) {
          const targetName = targetMatch[1];
          result.targetsWithSkip.push(targetName);
        }

        // Check if it's a declare readonly xxxValue property
        const valueMatch = propertyName.match(/^(\w+)Value$/);
        if (valueMatch && hasSkipComment) {
          const valueName = valueMatch[1];
          result.valuesWithSkip.push(valueName);
        }
      }

      // Check for method declarations
      if (ts.isMethodDeclaration(member) && ts.isIdentifier(member.name)) {
        const methodName = member.name.text;

        // Exclude lifecycle methods
        if (!['connect', 'disconnect', 'constructor'].includes(methodName)) {
          result.methods.push(methodName);
        }

        // Check method body for anti-patterns and querySelector calls
        if (member.body) {
          checkAntiPatterns(member.body, methodName);
          extractQuerySelectors(member.body, methodName);
        }
      }
    });
  }

  // Continue traversing
  ts.forEachChild(node, visitNode);
}

// Start traversal
visitNode(sourceFile);

// Output JSON result
console.log(JSON.stringify(result));
