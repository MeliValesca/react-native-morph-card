import * as React from 'react';

interface TimerState {
  seconds: number;
  phase: 'work' | 'rest';
  round: number;
}

const WORK_DURATION = 30;
const REST_DURATION = 10;

const CountdownContext = React.createContext<TimerState>({
  seconds: WORK_DURATION,
  phase: 'work',
  round: 1,
});

export function CountdownProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = React.useState<TimerState>({
    seconds: WORK_DURATION,
    phase: 'work',
    round: 1,
  });

  React.useEffect(() => {
    const interval = setInterval(() => {
      setState((prev) => {
        if (prev.seconds > 0) {
          return { ...prev, seconds: prev.seconds - 1 };
        }
        // Switch phase
        if (prev.phase === 'work') {
          return { seconds: REST_DURATION, phase: 'rest', round: prev.round };
        }
        // Next round
        const nextRound = prev.round >= 4 ? 1 : prev.round + 1;
        return { seconds: WORK_DURATION, phase: 'work', round: nextRound };
      });
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <CountdownContext.Provider value={state}>
      {children}
    </CountdownContext.Provider>
  );
}

export function useCountdown() {
  return React.useContext(CountdownContext);
}
