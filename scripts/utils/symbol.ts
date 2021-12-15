import { BigNumber } from "bignumber.js";

export const symbolToFelt = (symbol: string): string => {
  var utf8 = unescape(encodeURIComponent(symbol));

  var arr = [];
  for (var i = 0; i < utf8.length; i++) {
    arr.push(utf8.charCodeAt(i));
  }

  return arr.join("");
};

export const feltToSymbol = (symbol: string): string => {
  var chunks = [];

  for (var i = 0, charsLength = symbol.length; i < charsLength; i += 2) {
    chunks.push(+symbol.substring(i, i + 2));
  }

  return String.fromCharCode.apply(null, chunks);
};
