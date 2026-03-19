import * as React from 'react';

const CountdownContext = React.createContext(60);

export function CountdownProvider({ children }: { children: React.ReactNode }) {
  const [count, setCount] = React.useState(60);

  React.useEffect(() => {
    const interval = setInterval(() => {
      setCount((c) => (c <= 0 ? 60 : c - 1));
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <CountdownContext.Provider value={count}>
      {children}
    </CountdownContext.Provider>
  );
}

export function useCountdown() {
  return React.useContext(CountdownContext);
}
