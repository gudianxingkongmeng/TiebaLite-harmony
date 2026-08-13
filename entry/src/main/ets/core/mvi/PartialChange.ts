import UiState from './UiState';

export default interface PartialChange<S extends UiState> {
  reduce(oldState: S): S;
}
