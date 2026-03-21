// Re-export Drawflow as the default export of the UMD bundle.
// In LWC: window.OrchestrationEngine.default is the Drawflow class.
import Drawflow from 'drawflow';
import 'drawflow/dist/drawflow.min.css';

export default Drawflow;
