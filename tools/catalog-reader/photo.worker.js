// Segmentation adapted from Conecta Fotos (034db65), using U2NetP.
import * as ort from 'onnxruntime-web/wasm';

const side = 320;
const pixelCount = side * side;
let session;
ort.env.wasm.numThreads = 1;
ort.env.logLevel = 'error';

self.onmessage = async ({ data: { id, pixels, runtimeUrl } }) => {
  let input;
  let outputs;
  try {
    if (!session) {
      ort.env.wasm.wasmPaths = runtimeUrl;
      session = await ort.InferenceSession.create(runtimeUrl + 'u2netp.onnx', {
        executionProviders: ['wasm'],
        graphOptimizationLevel: 'all',
      });
    }
    const values = new Float32Array(pixelCount * 3);
    const mean = [.485, .456, .406];
    const std = [.229, .224, .225];
    let max = 1;
    for (let i = 0; i < pixels.length; i += 4) {
      max = Math.max(max, pixels[i], pixels[i + 1], pixels[i + 2]);
    }
    for (let c = 0; c < 3; c++) {
      for (let i = 0; i < pixelCount; i++) {
        values[c * pixelCount + i] = (pixels[i * 4 + c] / max - mean[c]) / std[c];
      }
    }
    input = new ort.Tensor('float32', values, [1, 3, side, side]);
    const outputName = session.outputNames[0];
    outputs = await session.run({ [session.inputNames[0]]: input }, [outputName]);
    const scores = outputs[outputName].data;
    let min = Infinity;
    let high = -Infinity;
    for (const value of scores) {
      min = Math.min(min, value);
      high = Math.max(high, value);
    }
    if (!Number.isFinite(min) || high - min < 1e-6) {
      throw Error('El recorte no pudo distinguir la pieza.');
    }
    const mask = Uint8Array.from(scores, value => Math.round(255 * (value - min) / (high - min)));
    self.postMessage({ id, mask }, [mask.buffer]);
  } catch (error) {
    self.postMessage({ id, error: error.message });
  } finally {
    input?.dispose();
    for (const output of Object.values(outputs ?? {})) output.dispose();
  }
};
