import UiState from './UiState';
import UiEvent from './UiEvent';
import { CommonUiEvent, CommonUiEventType } from './UiEvent';

type Observer<S> = (state: S) => void;
type EventObs<E> = (event: E) => void;

export default class BaseStateViewModel<S extends UiState, E extends UiEvent> {
  private _state: S;
  private _prevState: S | null = null;
  private observers: Observer<S>[] = [];
  private eventObservers: EventObs<E>[] = [];

  constructor(initialState: S) {
    this._state = initialState;
  }

  get state(): S {
    return this._state;
  }

  protected setState(newState: S): void {
    this._prevState = this._state;
    this._state = newState;
    for (const obs of this.observers) {
      obs(this._state);
    }
  }

  protected emitEvent(event: E): void {
    for (const obs of this.eventObservers) {
      obs(event);
    }
  }

  onStateChange(observer: Observer<S>): void {
    this.observers.push(observer);
  }

  onEvent(observer: EventObs<E>): void {
    this.eventObservers.push(observer);
  }

  cleanup(): void {
    this.observers = [];
    this.eventObservers = [];
  }
}
