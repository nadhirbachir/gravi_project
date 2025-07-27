using gravi_application.DTOs;
using gravi_application.Interfaces;
using gravi_application.Services;
using Microsoft.AspNetCore.Mvc;

namespace gravi_presentation.Controllers
{
    [ApiController]
    [Route("testapi/[controller]")]
    public class TestController : ControllerBase
    {
        private readonly IUserPersonFactoryService _userPersonFactoryService;

        // Inject the service via constructor
        public TestController(IUserPersonFactoryService userPersonFactoryService)
        {
            _userPersonFactoryService = userPersonFactoryService;
        }

        [HttpPost("Add_new_person")]
        public async Task<ActionResult<UserDTO>> AddUser([FromBody] AddUserDTO dto)
        {
            if (dto == null)
                return BadRequest(new { Error = "The user DTO cannot be null" });

            if (!ModelState.IsValid)
            {
                // Collect error messages from ModelState
                var errors = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();

                return BadRequest(new { Errors = errors });
            }

            try
            {
                var newUser = await _userPersonFactoryService.CreateUserWithPersonAsync(dto);

                if (newUser.NewUser != null)
                {
                    return Ok(new { Message = newUser.Message, NewUser = newUser.NewUser });
                }
                else
                {
                    return BadRequest(new { Message = newUser.Message });
                }
            }
            catch (Exception ex)
            {
                return BadRequest(new { Error = "The user was NOT added", ExceptionMessage = ex.Message });
            }
        }
    }

}
