import UiState from './UiState';
import UiIntent from './UiIntent';
import UiEvent from './UiEvent';
import PartialChange from './PartialChange';
import { CommonUiEvent, CommonUiEventType } from './UiEvent';

type StateObserver<S> = (state: S) => void;
type EventObserver<E> = (event: E) => void;

export default class BaseViewModel<I extends UiIntent, PC extends PartialChange<S>, S extends UiState, E extends UiEvent> {
  private _state: S;
  private stateObservers: StateObserver<S>[] = [];
  private eventObservers: EventObserver<E>[] = [];
  private stateHistory: S[] = [];

  constructor(initialState: S) {
    this._state = initialState;
  }

  get state(): S {
    return this._state;
  }

  protected setState(newState: S): void {
    this._state = newState;
    this.stateHistory.push(newState);
    for (const obs of this.stateObservers) {
      obs(this._state);
    }
  }

  send(intent: I): void {
  }

  protected dispatchEvent(event: E): void {
    for (const obs of this.eventObservers) {
      obs(event);
    }
  }

  onStateChange(observer: StateObserver<S>): void {
    this.stateObservers.push(observer);
  }

  onEvent(observer: EventObserver<E>): void {
    this.eventObservers.push(observer);
  }

  cleanup(): void {
    this.stateObservers = [];
    this.eventObservers = [];
  }
}
