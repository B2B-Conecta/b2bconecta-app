const side = 320;
let worker;
let nextId = 0;

export async function segment(bytes) {
  const bitmap = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = side;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  try {
    ctx.drawImage(bitmap, 0, 0, side, side);
    const alpha = ctx.getImageData(0, 0, side, side).data;
    let transparent = 0;
    for (let i = 3; i < alpha.length; i += 4) {
      if (alpha[i] < 10) transparent++;
    }
    if (transparent > side * side * .01) return new Uint8Array(side * side).fill(255);
    ctx.globalCompositeOperation = 'destination-over';
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, side, side);
    const { data } = ctx.getImageData(0, 0, side, side);

    const current = worker ??= new Worker(new URL('./photo.worker.js', import.meta.url), { type: 'module' });
    const id = ++nextId;
    const runtimeUrl = new URL(/* @vite-ignore */ '../segmentation/', import.meta.url).href;
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        current.terminate();
        if (worker === current) worker = undefined;
        finish(Error('El recorte tardó demasiado.'));
      }, 90000);
      function finish(error, mask) {
        clearTimeout(timer);
        current.removeEventListener('message', receive);
        current.removeEventListener('error', failed);
        if (error) reject(error);
        else resolve(mask);
      }
      function receive({ data: reply }) {
        if (reply.id === id) finish(reply.error && Error(reply.error), reply.mask);
      }
      function failed() {
        current.terminate();
        if (worker === current) worker = undefined;
        finish(Error('No se pudo iniciar el motor de recorte.'));
      }
      current.addEventListener('message', receive);
      current.addEventListener('error', failed);
      current.postMessage({ id, pixels: data, runtimeUrl }, [data.buffer]);
    });
  } finally {
    bitmap.close();
    canvas.width = canvas.height = 0;
  }
}
