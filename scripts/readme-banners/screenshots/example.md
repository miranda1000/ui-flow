# Kettle

- Start screen: **Welcome**
- 6 screens, 11 interactions

## Screens

### Welcome

Start screen.

| Interaction | Goes to |
|---|---|
| Click "Get started" | Menu |

Reached from: Profile (Click "Sign out")

### Menu

How to reach: Welcome → Click "Get started" → Menu

| Interaction | Goes to |
|---|---|
| Click "Caffè latte" | Caffè latte |
| Click "Cart" | Your order |
| Click "Profile tab" | Profile |

Reached from: Welcome (Click "Get started"), Caffè latte (Click "Back"), Order placed (after 5 seconds), Profile (Click "Back")

### Caffè latte

How to reach: Welcome → Click "Get started" → Menu → Click "Caffè latte" → Caffè latte

| Interaction | Goes to |
|---|---|
| Click "Back" | Menu |
| Click "Add to order" | Your order |

Reached from: Menu (Click "Caffè latte"), Your order (Click "Back")

### Your order

How to reach: Welcome → Click "Get started" → Menu → Click "Cart" → Your order

| Interaction | Goes to |
|---|---|
| Click "Back" | Caffè latte |
| Click "Place order" (payment is confirmed) | Order placed |

Reached from: Menu (Click "Cart"), Caffè latte (Click "Add to order")

### Order placed

How to reach: Welcome → Click "Get started" → Menu → Click "Cart" → Your order → Click "Place order" (payment is confirmed) → Order placed

> Goes back to the menu by itself; Track order is not designed yet.

| Interaction | Goes to |
|---|---|
| after 5 seconds | Menu |

Reached from: Your order (Click "Place order" (payment is confirmed))

### Profile

How to reach: Welcome → Click "Get started" → Menu → Click "Profile tab" → Profile

| Interaction | Goes to |
|---|---|
| Click "Back" | Menu |
| Click "Sign out" | Welcome |

Reached from: Menu (Click "Profile tab")

## Warnings

- Hotspot "Sign in" on "Welcome" does not lead anywhere.
- Hotspot "Track order" on "Order placed" does not lead anywhere.

