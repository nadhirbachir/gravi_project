using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Interfaces
{
    public interface IUserRepository
    {
        Task<(string Message, long? Result)> AddUserAsync(User newUser);
        Task<(string Message, bool Result)> UpdateUserAsync(User user);
        Task<(string Message, bool Result)> DeleteUserAsync(long userId, string passwordHash);
        Task<User?> FindUserByIdAsync(long? userId);
        Task<User?> FindUserByPersonIdAsync(long? personId);
        Task<User?> FindUserByEmailAsync(string? email);
        Task<User?> FindUserByUsernameAsync(string? username);
        Task<bool> UserExistsByPersonIdAsync(long? personId);
        Task<User?> LogUserAsync(string usernameOrEmail, string password);
    }
}
