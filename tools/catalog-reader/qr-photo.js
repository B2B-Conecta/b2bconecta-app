import { prepareZXingModule, readBarcodes } from 'zxing-wasm/reader';
import wasmUrl from 'zxing-wasm/reader/zxing_reader.wasm?url';

prepareZXingModule({ overrides: { locateFile: () => wasmUrl } });

export async function readPhotoQrs(bytes) {
  const image = await createImageBitmap(new Blob([bytes]));
  try {
    const canvas = document.createElement('canvas');
    const scale = Math.min(1, 2048 / Math.max(image.width, image.height));
    canvas.width = Math.max(1, Math.round(image.width * scale));
    canvas.height = Math.max(1, Math.round(image.height * scale));
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.fillStyle = '#fff';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const matches = await readBarcodes(
      context.getImageData(0, 0, canvas.width, canvas.height),
      { formats: ['QRCode'], tryHarder: true, maxNumberOfSymbols: 2 },
    );
    return matches.map(match => match.text);
  } finally {
    image.close();
  }
}
