---
title: "[ComponentName] Component Documentation"
author: "[Author Name]"
created: "[YYYY-MM-DD]"
updated: "[YYYY-MM-DD]"
version: "1.0"
tags: ["component", "react", "frontend", "ui"]
category: "Component Documentation"
status: "draft | review | published"
reviewers: ["frontend-team", "design-team"]
confluence_page_id: "[Confluence Page ID]"
component_path: "src/components/[ComponentName]"
figma_design: "[Figma URL]"
storybook_url: "[Storybook URL]"
---

# [ComponentName] Component

## Overview

[Brief description of what this component does and where it's used]

**Component Type**: [Presentation | Container | Layout | Form | Navigation]
**Design System**: [Component family or design system it belongs to]
**Status**: [Stable | Beta | Experimental | Deprecated]

---

## Table of Contents

- [Installation & Import](#installation--import)
- [Props API](#props-api)
- [Usage Examples](#usage-examples)
- [Variants & States](#variants--states)
- [Styling & Theming](#styling--theming)
- [Accessibility](#accessibility)
- [Browser Support](#browser-support)
- [Testing](#testing)

---

## Installation & Import

### Import Statement
```typescript
import { [ComponentName] } from '@/components/[ComponentName]';
// or
import [ComponentName] from '@/components/[ComponentName]/[ComponentName]';
```

### Dependencies
This component has the following dependencies:
- `react` (^18.0.0)
- `[other-dependency]` (^x.x.x)

---

## Props API

### [ComponentName] Props

```typescript
interface [ComponentName]Props {
  /** Brief description of the prop */
  propName: string;
  
  /** Optional prop with default value */
  optionalProp?: boolean;
  
  /** Union type prop */
  size?: 'small' | 'medium' | 'large';
  
  /** Function prop */
  onClick?: (event: MouseEvent) => void;
  
  /** Complex object prop */
  config?: {
    setting1: string;
    setting2: number;
  };
  
  /** Children prop */
  children: React.ReactNode;
  
  /** HTML attributes */
  className?: string;
  id?: string;
}
```

### Prop Details

| Prop | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| `propName` | `string` | - | ✅ | [Detailed description] |
| `optionalProp` | `boolean` | `false` | ❌ | [Detailed description] |
| `size` | `'small' \| 'medium' \| 'large'` | `'medium'` | ❌ | Controls component size |
| `onClick` | `function` | - | ❌ | Click event handler |
| `children` | `ReactNode` | - | ✅ | Component content |
| `className` | `string` | - | ❌ | Additional CSS classes |

---

## Usage Examples

### Basic Usage

```tsx
import { [ComponentName] } from '@/components/[ComponentName]';

function Example() {
  return (
    <[ComponentName] propName="value">
      Content goes here
    </[ComponentName]>
  );
}
```

### With All Props

```tsx
import { [ComponentName] } from '@/components/[ComponentName]';

function FullExample() {
  const handleClick = (event: MouseEvent) => {
    console.log('Clicked!', event);
  };

  return (
    <[ComponentName]
      propName="example"
      size="large"
      optionalProp={true}
      onClick={handleClick}
      className="custom-class"
      config={{
        setting1: "value1",
        setting2: 42
      }}
    >
      <div>Rich content example</div>
    </[ComponentName]>
  );
}
```

### With Conditional Rendering

```tsx
function ConditionalExample({ isVisible }: { isVisible: boolean }) {
  if (!isVisible) return null;

  return (
    <[ComponentName] propName="conditional">
      This content is conditionally rendered
    </[ComponentName]>
  );
}
```

---

## Variants & States

### Size Variants

#### Small
```tsx
<[ComponentName] size="small" propName="value">
  Small variant
</[ComponentName]>
```

#### Medium (Default)
```tsx
<[ComponentName] size="medium" propName="value">
  Medium variant
</[ComponentName]>
```

#### Large
```tsx
<[ComponentName] size="large" propName="value">
  Large variant
</[ComponentName]>
```

### Component States

#### Default State
```tsx
<[ComponentName] propName="default">
  Default state
</[ComponentName]>
```

#### Loading State
```tsx
<[ComponentName] propName="loading" isLoading={true}>
  Loading state
</[ComponentName]>
```

#### Error State
```tsx
<[ComponentName] propName="error" hasError={true}>
  Error state
</[ComponentName]>
```

#### Disabled State
```tsx
<[ComponentName] propName="disabled" disabled={true}>
  Disabled state
</[ComponentName]>
```

---

## Styling & Theming

### CSS Classes

The component applies the following CSS classes:

```css
/* Base component class */
.component-name {
  /* Base styles */
}

/* Size modifiers */
.component-name--small { /* Small size styles */ }
.component-name--medium { /* Medium size styles */ }
.component-name--large { /* Large size styles */ }

/* State modifiers */
.component-name--loading { /* Loading state styles */ }
.component-name--error { /* Error state styles */ }
.component-name--disabled { /* Disabled state styles */ }
```

### Custom Styling

#### Using CSS Modules
```css
/* ComponentName.module.css */
.customComponent {
  background-color: blue;
  border-radius: 8px;
}
```

```tsx
import styles from './ComponentName.module.css';

<[ComponentName] className={styles.customComponent} propName="styled">
  Custom styled component
</[ComponentName]>
```

#### Using Styled Components
```tsx
import styled from 'styled-components';
import { [ComponentName] } from '@/components/[ComponentName]';

const StyledComponent = styled([ComponentName])`
  background-color: ${props => props.theme.colors.primary};
  padding: ${props => props.theme.spacing.md};
`;
```

### Theming Variables

The component uses the following CSS custom properties:

```css
:root {
  --component-name-bg: #ffffff;
  --component-name-text: #000000;
  --component-name-border: #e0e0e0;
  --component-name-radius: 4px;
}
```

---

## Accessibility

### ARIA Attributes

The component automatically includes:

- `role`: [Appropriate ARIA role]
- `aria-label`: [When applicable]
- `aria-describedby`: [For additional descriptions]
- `aria-expanded`: [For expandable components]

### Keyboard Navigation

| Key | Action |
|-----|--------|
| `Tab` | [Navigation behavior] |
| `Enter` | [Activation behavior] |
| `Space` | [Activation behavior] |
| `Escape` | [Dismissal behavior] |
| `Arrow keys` | [Navigation behavior] |

### Screen Reader Support

- [Description of screen reader behavior]
- [Any special announcements or labels]
- [Focus management details]

### Color Contrast

All text in this component meets WCAG 2.1 AA standards:
- Normal text: 4.5:1 contrast ratio
- Large text: 3:1 contrast ratio

---

## Browser Support

| Browser | Version | Support Level |
|---------|---------|---------------|
| Chrome | 88+ | ✅ Full |
| Firefox | 85+ | ✅ Full |
| Safari | 14+ | ✅ Full |
| Edge | 88+ | ✅ Full |
| IE 11 | - | ❌ Not supported |

### Polyfills Required

For older browser support, you may need:
- [Polyfill 1] for [feature]
- [Polyfill 2] for [feature]

---

## Testing

### Unit Tests

```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { [ComponentName] } from './[ComponentName]';

describe('[ComponentName]', () => {
  it('renders with required props', () => {
    render(<[ComponentName] propName="test">Test content</[ComponentName]>);
    expect(screen.getByText('Test content')).toBeInTheDocument();
  });

  it('handles click events', () => {
    const handleClick = jest.fn();
    render(
      <[ComponentName] propName="test" onClick={handleClick}>
        Clickable
      </[ComponentName]>
    );
    
    fireEvent.click(screen.getByText('Clickable'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('applies custom className', () => {
    render(
      <[ComponentName] propName="test" className="custom-class">
        Content
      </[ComponentName]>
    );
    expect(screen.getByText('Content')).toHaveClass('custom-class');
  });
});
```

### Visual Testing

The component is covered by visual regression tests in:
- [Storybook stories](storybook-url)
- [Chromatic visual tests](chromatic-url)

### Accessibility Testing

```tsx
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

it('should not have accessibility violations', async () => {
  const { container } = render(
    <[ComponentName] propName="test">Accessible content</[ComponentName]>
  );
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

---

## Performance Considerations

### Bundle Size
- Component bundle size: [X KB gzipped]
- Dependencies: [List major dependencies and their sizes]

### Rendering Performance
- [Any performance considerations]
- [Optimization techniques used]
- [When to use React.memo or other optimizations]

### Best Practices
- [Performance best practices for this component]
- [Common performance pitfalls to avoid]

---

## Migration Guide

### From v1 to v2
[If applicable, include migration instructions for breaking changes]

```tsx
// Before (v1)
<[ComponentName] oldProp="value" />

// After (v2)
<[ComponentName] newProp="value" />
```

---

## Related Components

- [`RelatedComponent1`](./RelatedComponent1.md) - [Relationship description]
- [`RelatedComponent2`](./RelatedComponent2.md) - [Relationship description]
- [`ParentComponent`](./ParentComponent.md) - [Relationship description]

---

## Design Resources

- 🎨 [Figma Design](figma-url)
- 📚 [Storybook](storybook-url)
- 🎯 [Design System Guidelines](design-system-url)

---

## Changelog

### v2.1.0 (2024-02-01)
- Added new `variant` prop
- Improved accessibility with better ARIA labels
- Fixed focus management issues

### v2.0.0 (2024-01-15)
- **BREAKING**: Renamed `oldProp` to `newProp`
- Added TypeScript support
- Improved performance with React.memo

### v1.2.0 (2024-01-01)
- Added `size` variants
- Improved responsive behavior
- Bug fixes for edge cases

---

## Contributing

To contribute to this component:

1. Follow the [Component Development Guidelines](../contributing/component-guidelines.md)
2. Update tests and documentation
3. Test accessibility compliance
4. Update Storybook stories

---

**Document Information:**
- **Component Version**: [Version]
- **Last Updated**: [Date]
- **Next Review**: [Date]
- **Component Owner**: [Team Name]
- **Confluence**: [Link to Confluence page]