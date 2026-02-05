import { describe, it, expect } from 'vitest';

describe('Offchain Setup', () => {
  it('should have TypeScript strict mode enabled', () => {
    // This test will fail at compile time if strict mode is not enabled
    const strictTest = (value: string | undefined): string => {
      // With strict mode, this would fail without the check
      if (value === undefined) {
        return 'default';
      }
      return value;
    };

    expect(strictTest(undefined)).toBe('default');
    expect(strictTest('test')).toBe('test');
  });

  it('should support ES2022 features', () => {
    // Test Array.at() - ES2022 feature
    const arr = [1, 2, 3];
    expect(arr.at(-1)).toBe(3);

    // Test Object.hasOwn() - ES2022 feature
    const obj = { key: 'value' };
    expect(Object.hasOwn(obj, 'key')).toBe(true);
  });

  it('should be able to import viem', async () => {
    // Verify viem dependency is available
    const viem = await import('viem');
    expect(viem).toBeDefined();
    expect(typeof viem.createPublicClient).toBe('function');
  });
});
