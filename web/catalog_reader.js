globalThis.b2bCatalogReader = {
  async read(bytes, filename, progress) {
    try {
      const reader = await import('./assets/catalog-reader/reader.js');
      return await reader.read(bytes, filename, progress);
    } catch {
      return {error: 'El lector web no está disponible. Recarga la página o usa un archivo XLSX o CSV.'};
    }
  },
};
globalThis.b2bCatalogReader.preparePhoto = async (bytes) => {
  const reader = await import('./assets/catalog-reader/reader.js');
  return reader.preparePhoto(bytes);
};
