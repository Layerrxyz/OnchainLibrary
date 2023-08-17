const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const fs = require("fs");
const path = require("path");

describe("OnchainLibrary", function () {

  async function deployLibrary() {
    
    // Contracts are deployed using the first signer/account by default
    const [owner, address2, address3, address4, address5, address6] = await ethers.getSigners();

    const LibraryFactory = await ethers.getContractFactory("OnchainLibrary");
    const library = await LibraryFactory.deploy();

    return { library, owner, address2, address3 };
  }

  describe("Upload", function () {
    it("Should upload data", async function () {
      const { library, owner, address2, address3 } = await loadFixture(deployLibrary);
      
      let fileData = fs.readFileSync("./test/files/p5.min.js.gz.txt", "binary");
      let fileBytes = "0x";
      let chunkBytes = "";
      let byteArrays = [];
      for(let i = 0;i < fileData.length;i++) {
        if(byteArrays.length < (parseInt(Math.floor((i / 24575))) + 1)) { byteArrays.push([]);  }
        byteArrays[(parseInt(Math.floor((i / 24575))))].push(fileData.charCodeAt(i));
      }
      await library.addAsset("p5js", "0xc4d4969c034b519fc30ab72adca7bf038639455f13687a0ebc8dfece74c6ec80", byteArrays.length);
      for(let i = 0;i < byteArrays.length;i++) {
        console.log("Asset #: " + 1);
        console.log("Chunk #: " + i);
        console.log(ethers.hexlify(new Uint8Array(byteArrays[i])));
        chunkBytes = ethers.hexlify(new Uint8Array(byteArrays[i]));
        fileBytes += chunkBytes.substring(2);
        await library.uploadChunk(1, i, chunkBytes);
      }
      await library.finalizeAsset(1);
      console.log("File hash: " + ethers.sha256(fileBytes));
      
      fileBytes = "0x";
      chunkBytes = "";
      fileData = fs.readFileSync("./test/files/gunzip.min.js.txt", "binary");
      byteArrays = [];
      for(let i = 0;i < fileData.length;i++) {
        if(byteArrays.length < (parseInt(Math.floor((i / 24575))) + 1)) { byteArrays.push([]);  }
        byteArrays[(parseInt(Math.floor((i / 24575))))].push(fileData.charCodeAt(i));
      }
      await library.addAsset("gunzip", "0x88eddf840ac68d8484a013f4064edbac956b87c51830237a0bf93a0476aee654", byteArrays.length);
      for(let i = 0;i < byteArrays.length;i++) {
        console.log("Asset #: " + 2);
        console.log("Chunk #: " + i);
        console.log(ethers.hexlify(new Uint8Array(byteArrays[i])));
        chunkBytes = ethers.hexlify(new Uint8Array(byteArrays[i]));
        fileBytes += chunkBytes.substring(2);
        await library.uploadChunk(2, i, chunkBytes);
      }
      await library.finalizeAsset(2);
      console.log("File hash: " + ethers.sha256(fileBytes));
      
      fileBytes = "0x";
      chunkBytes = "";
      fileData = fs.readFileSync("./test/files/layerrsOfSummer.js.txt", "binary");
      byteArrays = [];
      for(let i = 0;i < fileData.length;i++) {
        if(byteArrays.length < (parseInt(Math.floor((i / 24575))) + 1)) { byteArrays.push([]);  }
        byteArrays[(parseInt(Math.floor((i / 24575))))].push(fileData.charCodeAt(i));
      }
      await library.addAsset("layerrsOfSummer", "0x9845bd0e7ee1752774533ee255f17274fcc410b8f33ae58e4f6736fadd6a27da", byteArrays.length);
      for(let i = 0;i < byteArrays.length;i++) {
        console.log("Asset #: " + 3);
        console.log("Chunk #: " + i);
        console.log(ethers.hexlify(new Uint8Array(byteArrays[i])));
        chunkBytes = ethers.hexlify(new Uint8Array(byteArrays[i]));
        fileBytes += chunkBytes.substring(2);
        await library.uploadChunk(3, i, chunkBytes);
      }
      await library.finalizeAsset(3);

      console.log(await library.getScript("", "0x0000000000000000000000000000000000000000000000000000000000000002"));
      console.log(await library.getDataChunkAddress(ethers.hexlify(new Uint8Array(byteArrays[0]))));

      console.log(await library.getAssetBytes(1)); 
      console.log(await library.getAssetBase64(1));
      console.log(await library.getAssetActualSHA256Hash(1));
      console.log(await library.validateActualAndExpectedHash(1));
      console.log(await library.validateActualAndExpectedHashOnchain(1));
      console.log(await library.searchCatalogByExpectedHash("0xc4d4969c034b519fc30ab72adca7bf038639455f13687a0ebc8dfece74c6ec80"));
      console.log(await library.searchCatalogByValidatedHash("0xc4d4969c034b519fc30ab72adca7bf038639455f13687a0ebc8dfece74c6ec80"));
      console.log(await library.searchCatalogByName("p5js"));
      console.log(await library.getAssetBase64(2));
      console.log(await library.getAssetActualSHA256Hash(2));
      console.log(await library.validateActualAndExpectedHash(2));
      console.log(await library.validateActualAndExpectedHashOnchain(2));
      console.log(await library.searchCatalogByName("gunzip"));
    });
  });
});
